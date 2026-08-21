# frozen_string_literal: true

RSpec.describe "Admin prohibition during impersonation", :with_rbac_setup, type: :request do
  let(:operator) { create(:user, :role_impersonation_operator) }
  let(:admin_target) { create(:user, :role_admin) }
  let(:member_target) { create(:user, roles: ["member"]) }
  let!(:session) { create(:impersonation_session, actor: operator, target: admin_target) }
  let(:headers) { authenticate_impersonation_with_bearer!(operator, session) }

  def error_code
    response.parsed_body.dig("errors", 0, "code")
  end

  it "allows ordinary admin access without overlay" do
    get "/admin/users", headers: authenticate_request_with_bearer!(operator)

    expect(response).to have_http_status(:ok)
  end

  it "rejects impersonated GET /admin/users with 418" do
    get "/admin/users", headers: headers

    expect(response).to have_http_status(418)
    expect(error_code).to eq("admin_unavailable_during_impersonation")
  end

  context "when the overlay actor can mutate identity" do
    let(:operator) { create(:user, :role_admin) }

    it "rejects impersonated PATCH /admin/users/:id/name with 418" do
      patch "/admin/users/#{member_target.id}/name",
        params: { firstName: "Ada", lastName: "Lovelace" },
        headers: headers

      expect(response).to have_http_status(418)
      expect(error_code).to eq("admin_unavailable_during_impersonation")
    end
  end

  context "when the overlay actor can assign roles" do
    let(:operator) { create(:user, :role_rbac_admin) }

    before do
      patch "/admin/users/#{member_target.id}/roles",
        params: { roles: ["member"] },
        headers: headers
    end

    it { expect(response).to have_http_status(418) }

    it { expect(error_code).to eq("admin_unavailable_during_impersonation") }
  end

  it "rejects impersonated GET /admin/audit-events with 418" do
    get "/admin/audit-events", headers: headers

    expect(response).to have_http_status(418)
    expect(error_code).to eq("admin_unavailable_during_impersonation")
  end

  it "rejects impersonated POST /admin/messaging/announcements with 418" do
    post "/admin/messaging/announcements",
      params: { title: "x", body: "y", audience: "all_users", campaignIdentity: "c1" },
      headers: headers

    expect(response).to have_http_status(418)
    expect(error_code).to eq("admin_unavailable_during_impersonation")
  end

  context "when the effective target could otherwise start impersonation" do
    let(:admin_target) { create(:user, :role_impersonation_operator) }

    it "rejects impersonated impersonation start with 418" do
      post "/admin/users/#{member_target.id}/impersonation-sessions", headers: headers

      expect(response).to have_http_status(418)
      expect(error_code).to eq("admin_unavailable_during_impersonation")
    end
  end

  context "when the actor is an owner" do
    let(:operator) { create(:user, :role_owner) }
    let(:admin_target) { create(:user, :role_owner) }

    it "still rejects admin users with 418" do
      get "/admin/users", headers: headers

      expect(response).to have_http_status(418)
      expect(error_code).to eq("admin_unavailable_during_impersonation")
    end
  end

  it "allows GET /admin/workspace and disables every tool" do
    get "/admin/workspace", headers: headers

    expect(response).to have_http_status(:ok)
    tools = response.parsed_body.dig("data", "tools")
    expect(tools).to be_present
    expect(tools).to all(
      include(
        "availability" => include(
          "enabled" => false,
          "reason" => CommandTower::AdminScope::ManifestProjection::IMPERSONATION_DISABLED_REASON
        )
      )
    )
  end

  it "allows stop while overlay is active" do
    delete "/auth/impersonation-session", headers: headers

    expect(response).to have_http_status(:ok)
  end

  context "when the overlay is expired" do
    let!(:session) do
      create(
        :impersonation_session,
        actor: operator,
        target: admin_target,
        idle_expires_at: 1.minute.ago,
        absolute_expires_at: 1.hour.from_now
      )
    end

    it "rejects admin users with impersonation expiry not 418" do
      get "/admin/users", headers: headers

      expect(response).to have_http_status(:unauthorized)
      expect(error_code).to eq("impersonation_session_expired")
    end
  end
end

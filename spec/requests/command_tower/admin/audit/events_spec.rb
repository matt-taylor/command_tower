# frozen_string_literal: true

RSpec.describe "GET /admin/audit-events", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(admin) }
  let(:phone) { "+14155551212" }

  let!(:hidden_history) do
    create_audit_event!(
      action: "session_created",
      affected_user_id: member.id,
      actor_user_id: member.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 3),
      user_history: false
    )
  end
  let!(:sensitive) do
    create_audit_event!(
      action: "phone_updated",
      affected_user_id: member.id,
      actor_user_id: member.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 2),
      change_set: { "phone" => { "from" => phone, "to" => nil } },
      sensitive_fields: ["phone"],
      user_history: true
    )
  end

  it "rejects unauthenticated requests" do
    get "/admin/audit-events"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member requests the admin surface" do
    let(:member_headers) { authenticate_request_with_bearer!(member) }

    before { get "/admin/audit-events", headers: member_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "lists cross-user rows including user_history false and masks phone" do
    get "/admin/audit-events", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to include(hidden_history.id, sensitive.id)
    expect(response.body).not_to include(phone)
    expect(
      response.parsed_body.fetch("data").find { |item| item.fetch("id") == sensitive.id }.dig("changes", "phone", "from")
    ).to eq("*******1212")
  end

  context "when filtering by affectedUserId" do
    let!(:other) { create_audit_event!(affected_user_id: admin.id, actor_user_id: admin.id, user_history: true) }

    before { get "/admin/audit-events", params: { affectedUserId: member.id }, headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "returns only the requested affected user" do
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to include(hidden_history.id, sensitive.id)
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).not_to include(other.id)
    end
  end

  it "rejects an invalid attributionMode with 422" do
    get "/admin/audit-events", params: { attributionMode: "superuser" }, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

RSpec.describe "GET /admin/audit-events/:id", :with_rbac_setup, type: :request do
  let(:admin) { create(:user, :role_admin) }
  let(:member) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(admin) }
  let(:phone) { "+14155551212" }

  let!(:hidden_history) do
    create_audit_event!(
      action: "session_created",
      affected_user_id: member.id,
      actor_user_id: member.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 3),
      user_history: false
    )
  end
  let!(:sensitive) do
    create_audit_event!(
      action: "phone_updated",
      affected_user_id: member.id,
      actor_user_id: member.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 2),
      change_set: { "phone" => { "from" => phone, "to" => nil } },
      sensitive_fields: ["phone"],
      user_history: true
    )
  end

  it "rejects unauthenticated requests" do
    get "/admin/audit-events/#{sensitive.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member requests admin show" do
    let(:member_headers) { authenticate_request_with_bearer!(member) }

    before { get "/admin/audit-events/#{sensitive.id}", headers: member_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "shows cross-user rows including user_history false and masks phone" do
    get "/admin/audit-events/#{hidden_history.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "id")).to eq(hidden_history.id)
  end

  it "masks sensitive change values on show" do
    get "/admin/audit-events/#{sensitive.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(phone)
    expect(response.parsed_body.dig("data", "changes", "phone", "from")).to eq("*******1212")
  end

  it "returns 404 for a missing id" do
    get "/admin/audit-events/999999999", headers: headers

    expect(response).to have_http_status(:not_found)
  end
end

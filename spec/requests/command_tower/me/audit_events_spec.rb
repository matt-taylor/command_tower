# frozen_string_literal: true

RSpec.describe "GET /me/audit-events", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:other) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:phone) { "+14155551212" }

  let!(:own_visible) do
    create_audit_event!(
      action: "phone_updated",
      affected_user_id: user.id,
      actor_user_id: user.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 2),
      change_set: { "phone" => { "from" => phone, "to" => "+14155559999" } },
      sensitive_fields: ["phone"],
      user_history: true
    )
  end
  let!(:own_hidden) do
    create_audit_event!(
      action: "session_created",
      affected_user_id: user.id,
      actor_user_id: user.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 3),
      user_history: false
    )
  end
  let!(:acted_on_other) do
    create_audit_event!(
      action: "role_assigned",
      affected_user_id: other.id,
      actor_user_id: user.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 4),
      user_history: true
    )
  end
  let!(:impersonated) do
    create_audit_event!(
      action: "password_changed",
      affected_user_id: user.id,
      actor_user_id: 99,
      originating_administrator_id: 99,
      impersonation_active: true,
      attribution_mode: "impersonation",
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 1),
      user_history: true
    )
  end

  it "rejects unauthenticated requests" do
    get "/me/audit-events"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when the caller lacks roles" do
    let(:unprivileged_user) { create(:user, roles: []) }
    let(:unprivileged_headers) { authenticate_request_with_bearer!(unprivileged_user) }

    before { get "/me/audit-events", headers: unprivileged_headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  it "lists only the caller's user-history rows including impersonation-shaped facts" do
    get "/me/audit-events", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to eq([own_visible.id, impersonated.id])
    expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).not_to include(own_hidden.id, acted_on_other.id)
    expect(response.parsed_body.dig("meta", "totalCount")).to eq(2)
  end

  it "ignores a target-user query param and never returns raw phone" do
    get "/me/audit-events", params: { affectedUserId: other.id }, headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include(phone)
    expect(response.body).not_to include("+14155559999")
    expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).not_to include(acted_on_other.id)
    expect(response.parsed_body.dig("data", 0, "changes", "phone", "from")).to eq("*******1212")
  end

  it "rejects an invalid eventName with 422" do
    get "/me/audit-events", params: { eventName: "Not Valid" }, headers: headers

    expect(response).to have_http_status(:unprocessable_entity)
  end
end

RSpec.describe "GET /me/audit-events/:id", :with_rbac_setup, type: :request do
  let(:user) { create(:user, roles: ["member"]) }
  let(:other) { create(:user, roles: ["member"]) }
  let(:headers) { authenticate_request_with_bearer!(user) }
  let(:phone) { "+14155551212" }

  let!(:own_visible) do
    create_audit_event!(
      action: "phone_updated",
      affected_user_id: user.id,
      actor_user_id: user.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 2),
      change_set: { "phone" => { "from" => phone, "to" => "+14155559999" } },
      sensitive_fields: ["phone"],
      user_history: true
    )
  end
  let!(:own_hidden) do
    create_audit_event!(
      action: "session_created",
      affected_user_id: user.id,
      actor_user_id: user.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 3),
      user_history: false
    )
  end
  let!(:other_visible) do
    create_audit_event!(
      action: "role_assigned",
      affected_user_id: other.id,
      actor_user_id: other.id,
      occurred_at: Time.utc(2026, 8, 16, 12, 0, 4),
      user_history: true
    )
  end

  it "rejects unauthenticated requests" do
    get "/me/audit-events/#{own_visible.id}"

    expect(response).to have_http_status(:unauthorized)
  end

  it "shows an own user-history row and masks phone" do
    get "/me/audit-events/#{own_visible.id}", headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.dig("data", "id")).to eq(own_visible.id)
    expect(response.parsed_body.dig("data", "eventLabel")).to eq("Phone updated")
    expect(response.body).not_to include(phone)
    expect(response.parsed_body.dig("data", "changes", "phone", "from")).to eq("*******1212")
  end

  it "returns 404 for another user's event" do
    get "/me/audit-events/#{other_visible.id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns 404 for own non-user-history events" do
    get "/me/audit-events/#{own_hidden.id}", headers: headers

    expect(response).to have_http_status(:not_found)
  end
end

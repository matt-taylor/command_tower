# frozen_string_literal: true

RSpec.describe "GET audit-events/filter-options", :with_rbac_setup, type: :request do
  describe "GET /admin/audit-events/filter-options" do
    let(:admin) { create(:user, :role_admin) }
    let(:headers) { authenticate_request_with_bearer!(admin) }

    it "returns registry event options with tags and attribution modes" do
      get "/admin/audit-events/filter-options", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body.fetch("data")
      session = body.fetch("eventNames").find { |entry| entry["value"] == "session_created" }
      expect(session).to include(
        "value" => "session_created",
        "label" => "Session created",
        "tags" => %w[authentication security session]
      )
      expect(body.fetch("attributionModes").map { |entry| entry["value"] }).to eq(
        CommandTower::Audit::Event::ATTRIBUTION_MODES
      )
      expect(body.fetch("subjectTypes")).to include(
        "value" => "User",
        "label" => "User"
      )
    end
  end

  describe "GET /me/audit-events/filter-options" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    it "returns user-history event options without attribution modes" do
      get "/me/audit-events/filter-options", headers: headers

      expect(response).to have_http_status(:ok)
      body = response.parsed_body.fetch("data")
      values = body.fetch("eventNames").map { |entry| entry["value"] }
      expect(values).to include("email_verified")
      expect(values).not_to include("session_created")
      expect(body.fetch("attributionModes")).to eq([])
      expect(body.fetch("subjectTypes").map { |entry| entry["value"] }).to include("User")
      email = body.fetch("eventNames").find { |entry| entry["value"] == "email_verified" }
      expect(email["tags"]).to include("identity", "verification", "email")
    end
  end
end

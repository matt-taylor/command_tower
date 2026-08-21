# frozen_string_literal: true

RSpec.describe "GET /admin/workspace", :with_rbac_setup, type: :request do
  it "rejects unauthenticated requests" do
    get "/admin/workspace"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member requests the workspace" do
    let(:member) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(member) }

    before { get "/admin/workspace", headers: headers }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "when a host admin requests the workspace" do
    let(:admin) { create(:user, :role_admin) }
    let(:headers) { authenticate_request_with_bearer!(admin) }

    before { get "/admin/workspace", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "returns RBAC-filtered CommandTower tools without registry internals" do
      expect(response.parsed_body.dig("data", "tools").map { |tool| tool.fetch("id") }).to eq(%w[messaging users audit])
      expect(response.parsed_body.dig("data", "tools").first.keys).to contain_exactly(
        "id", "label", "description", "route", "group", "sortOrder", "icon"
      )
      expect(
        response.parsed_body.dig("data", "tools").find { |tool| tool["id"] == "audit" }.fetch("description")
      ).to eq("Browse account and administrative audit history.")
      expect(response.body).not_to include("command_tower")
      expect(response.body).not_to include("required_entity")
      expect(response.body).not_to include("ToolDefinition")
    end
  end

  context "when an audit operator requests the workspace" do
    let(:operator) { create(:user, roles: ["audit_operator"]) }
    let(:headers) { authenticate_request_with_bearer!(operator) }

    before { get "/admin/workspace", headers: headers }

    it "returns only the audit tool" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "tools").map { |tool| tool.fetch("id") }).to eq(%w[audit])
    end
  end

  context "when a messaging operator requests the workspace" do
    let(:operator) { create(:user, roles: ["messaging_operator"]) }
    let(:headers) { authenticate_request_with_bearer!(operator) }

    before { get "/admin/workspace", headers: headers }

    it "returns only the messaging tool" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "tools").map { |tool| tool.fetch("id") }).to eq(%w[messaging])
    end
  end

  context "when an owner requests the workspace" do
    let(:owner) { create(:user, :role_owner) }
    let(:headers) { authenticate_request_with_bearer!(owner) }

    before { get "/admin/workspace", headers: headers }

    it "includes the dummy host tool" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "tools").map { |tool| tool.fetch("id") }).to include(
        "users", "audit", "messaging", "dummy_admin_example"
      )
    end
  end
end

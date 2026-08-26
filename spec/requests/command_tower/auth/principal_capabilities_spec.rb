# frozen_string_literal: true

RSpec.describe "GET /auth/principal-capabilities", :with_rbac_setup, type: :request do
  it "rejects unauthenticated requests" do
    get "/auth/principal-capabilities"

    expect(response).to have_http_status(:unauthorized)
  end

  context "when a member requests principal capabilities" do
    let(:member) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(member) }

    before { get "/auth/principal-capabilities", headers: headers }

    it { expect(response).to have_http_status(:ok) }

    it "returns me_audit_events when the host grants that entity to member" do
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(%w[me_audit_events])
      expect(response.body).not_to include("admin")
      expect(response.body).not_to include("member")
      expect(response.body).not_to include("requiredEntity")
      expect(response.body).not_to include("allow_everything")
    end
  end

  context "when an audit operator requests principal capabilities" do
    let(:operator) { create(:user, roles: ["audit_operator"]) }
    let(:headers) { authenticate_request_with_bearer!(operator) }

    before { get "/auth/principal-capabilities", headers: headers }

    it "returns workspace and audit capabilities only" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(
        %w[admin_audit_events admin_workspace]
      )
    end
  end

  context "when a messaging operator requests principal capabilities" do
    let(:operator) { create(:user, roles: ["messaging_operator"]) }
    let(:headers) { authenticate_request_with_bearer!(operator) }

    before { get "/auth/principal-capabilities", headers: headers }

    it "returns workspace and messaging capabilities only" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(
        %w[admin_messaging_announcements admin_workspace]
      )
    end
  end

  context "when a host admin requests principal capabilities" do
    let(:admin) { create(:user, :role_admin) }
    let(:headers) { authenticate_request_with_bearer!(admin) }

    before { get "/auth/principal-capabilities", headers: headers }

    it "returns all CT Admin projectable capabilities" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(
        %w[admin_audit_events admin_messaging_announcements admin_rbac_assignments admin_users admin_users_update admin_workspace]
      )
    end
  end

  context "when an impersonation operator requests principal capabilities" do
    let(:operator) { create(:user, :role_impersonation_operator) }
    let(:headers) { authenticate_request_with_bearer!(operator) }

    before { get "/auth/principal-capabilities", headers: headers }

    it "returns users and impersonation without the rest of Admin" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(
        %w[admin_impersonation admin_users admin_workspace]
      )
    end
  end

  context "when an owner requests principal capabilities" do
    let(:owner) { create(:user, :role_owner) }
    let(:headers) { authenticate_request_with_bearer!(owner) }

    before { get "/auth/principal-capabilities", headers: headers }

    it "returns all registered projectable capabilities including host additive" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(
        %w[admin_audit_events admin_impersonation admin_messaging_announcements admin_rbac_assignments admin_users admin_users_update admin_workspace dummy_admin_example me_audit_events]
      )
    end
  end

  context "when a user has multiple roles that grant overlapping capabilities" do
    let(:user) { create(:user, roles: %w[audit_operator messaging_operator]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { get "/auth/principal-capabilities", headers: headers }

    it "unions and deduplicates possessed capabilities" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "principalCapabilities")).to eq(
        %w[admin_audit_events admin_messaging_announcements admin_workspace]
      )
    end
  end

  context "with an unverified email over cookie" do
    let(:user) { create(:user, :unvalidated_email, roles: ["member"], created_at: 5.minutes.ago) }
    let(:cookie_name) { CommandTower.config.jwt.cookie.name }

    before do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = true
        config.login.plain_text.email_verify.enable = true
      end
      cookies[cookie_name] = login_token_for(user)
      get "/auth/principal-capabilities"
    end

    after do
      CommandTower.configure do |config|
        config.jwt.cookie.enabled = false
      end
    end

    it { expect(response).to have_http_status(:precondition_failed) }
  end
end

# frozen_string_literal: true

RSpec.describe "GET /auth/session", :with_rbac_setup, type: :request do
  subject(:make_request) { get path, headers: headers }

  let(:path) { "/auth/session" }
  let(:headers) { {} }
  let(:expire_header) { CommandTower::Jwt::AuthorizationHelper::AUTHENTICATION_EXPIRE_HEADER }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid Bearer token" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns user and tokenExpiresAt" do
      expect(response.parsed_body["data"]["user"]).to include(
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "emailValidated" => true
      )
      expect(response.parsed_body["data"]["tokenExpiresAt"]).to be_present
    end

    it "sets the expire header" do
      expect(response.headers[expire_header]).to be_present
    end
  end

  context "without a role mapped onto the action" do
    let(:user) { create(:user, roles: []) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }
  end

  context "with X-Authorization-Reset" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) do
      authenticate_request_with_bearer!(user).merge(
        "X-Authorization-Reset" => "true"
      )
    end

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns a refreshed token header" do
      expect(response.headers["X-Authorization-Reset"]).to be_present
    end
  end
end

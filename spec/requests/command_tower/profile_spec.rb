# frozen_string_literal: true

RSpec.describe "GET /profile", :with_rbac_setup, type: :request do
  subject(:make_request) { get path, headers: headers }

  let(:path) { "/profile" }
  let(:headers) { {} }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid Bearer token" do
    let(:user) { create(:user, roles: ["member"]) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns the UserSerializer payload" do
      expect(response.parsed_body["data"]).to include(
        "id" => user.id,
        "email" => user.email,
        "username" => user.username,
        "firstName" => user.first_name,
        "lastName" => user.last_name,
        "emailValidated" => true,
        "roles" => ["member"]
      )
      expect(response.parsed_body["data"]).not_to have_key("fullName")
      expect(response.parsed_body["data"]).not_to have_key("capabilities")
    end
  end

  context "without a role mapped onto the action" do
    let(:user) { create(:user, roles: []) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }
  end
end

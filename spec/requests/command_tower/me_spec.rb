# frozen_string_literal: true

RSpec.describe "GET /me", :with_rbac_setup, type: :request do
  subject(:make_request) { get path, headers: headers }

  let(:path) { "/me" }
  let(:headers) { {} }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid Bearer token" do
    let(:user) { create(:user, roles: ["member"], first_name: "Ada", last_name: "Lovelace") }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns the account payload" do
      expect(response.parsed_body["data"]).to include(
        "id" => user.id,
        "firstName" => "Ada",
        "lastName" => "Lovelace",
        "fullName" => "Ada Lovelace",
        "email" => user.email,
        "username" => user.username,
        "emailValidated" => true
      )
      expect(response.parsed_body["data"]["capabilities"]).to include(
        "editName" => { "enabled" => true },
        "changePassword" => { "enabled" => true },
        "verifyEmail" => { "enabled" => false }
      )
      expect(response.parsed_body["data"]["createdAt"]).to be_present
    end
  end

  context "without a role mapped onto the action" do
    let(:user) { create(:user, roles: []) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:forbidden) }
  end
end

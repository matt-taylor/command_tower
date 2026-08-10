# frozen_string_literal: true

RSpec.describe "PATCH /me/password", :with_rbac_setup, type: :request do
  subject(:make_request) { patch path, params: params, headers: headers, as: :json }

  let(:path) { "/me/password" }
  let(:headers) { {} }
  let(:stored_password) { "password1234abcdef" }
  let(:new_password) { "newpassword5678ghij" }
  let(:params) do
    {
      currentPassword: stored_password,
      password: new_password,
      passwordConfirmation: new_password
    }
  end

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid password change" do
    let(:user) { create(:user, roles: ["member"], password: stored_password, password_confirmation: stored_password) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns a success message only" do
      expect(response.parsed_body["data"]).to eq("message" => "Password updated successfully.")
    end

    it "rotates the verifier so the prior token fails" do
      get "/auth/session", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with an incorrect current password" do
    let(:user) { create(:user, roles: ["member"], password: stored_password, password_confirmation: stored_password) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) do
      {
        currentPassword: "wrong-password-here",
        password: new_password,
        passwordConfirmation: new_password
      }
    end

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end

  context "with missing fields" do
    let(:user) { create(:user, roles: ["member"], password: stored_password, password_confirmation: stored_password) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) { { currentPassword: stored_password } }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end
end

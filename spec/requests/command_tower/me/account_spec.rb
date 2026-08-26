# frozen_string_literal: true

RSpec.describe "DELETE /me/account", :with_rbac_setup, type: :request do
  subject(:make_request) { delete path, params: params, headers: headers, as: :json }

  let(:path) { "/me/account" }
  let(:headers) { {} }
  let(:stored_password) { "password1234abcdef" }
  let(:params) { { password: stored_password } }

  context "without authentication" do
    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a valid account deletion" do
    let(:user) { create(:user, roles: ["member"], password: stored_password, password_confirmation: stored_password) }
    let(:headers) { authenticate_request_with_bearer!(user) }

    before { make_request }

    it { expect(response).to have_http_status(:ok) }

    it "returns a success message" do
      expect(response.parsed_body["data"]).to eq("message" => "Your account has been deleted")
    end

    it "tombstones the user and revokes the session" do
      expect(user.reload.deleted_at).to be_present
      get "/auth/session", headers: headers
      expect(response).to have_http_status(:unauthorized)
    end

    it "persists account_deleted audit" do
      expect(CommandTower::Audit::Event.where(action: "account_deleted", affected_user_id: user.id)).to exist
    end
  end

  context "with an incorrect password" do
    let(:user) { create(:user, roles: ["member"], password: stored_password, password_confirmation: stored_password) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) { { password: "wrong-password-here" } }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end

  context "with missing password" do
    let(:user) { create(:user, roles: ["member"], password: stored_password, password_confirmation: stored_password) }
    let(:headers) { authenticate_request_with_bearer!(user) }
    let(:params) { {} }

    before { make_request }

    it { expect(response).to have_http_status(:unprocessable_entity) }
  end
end

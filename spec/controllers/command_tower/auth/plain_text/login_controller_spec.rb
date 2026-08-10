# frozen_string_literal: true

RSpec.describe CommandTower::Auth::PlainText::LoginController, type: :controller do
  routes { CommandTower::Engine.routes }

  describe "#create" do
    subject(:make_request) { post :create, params: params }

    let(:password) { "password1234" }

    context "with blank credentials" do
      let(:params) { { identifier: "", password: "" } }

      before { make_request }

      it { expect(response).to have_http_status(:unauthorized) }

      it "returns invalid_credentials" do
        expect(response.parsed_body["errors"].first["code"]).to eq("invalid_credentials")
      end
    end

    context "with valid credentials" do
      let(:user) { create(:user, password: password) }
      let(:params) { { identifier: user.email, password: password } }

      before { make_request }

      it { expect(response).to have_http_status(:created) }

      it "returns user and token in the envelope" do
        expect(response.parsed_body["data"]["user"]["email"]).to eq(user.email)
        expect(response.parsed_body["data"]["token"]).to be_present
        expect(response.parsed_body["data"]["tokenExpiresAt"]).to be_present
      end
    end
  end
end

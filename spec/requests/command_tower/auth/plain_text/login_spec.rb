# frozen_string_literal: true

RSpec.describe "POST /auth/plain-text/login", type: :request do
  subject(:make_request) { post path, params: params, as: :json }

  let(:path) { "/auth/plain-text/login" }
  let(:password) { "password1234" }

  context "with valid email credentials" do
    let(:user) { create(:user, password: password, roles: ["member"]) }
    let(:params) { { identifier: user.email, password: password } }

    it "returns created" do
      make_request
      expect(response).to have_http_status(:created)
    end

    context "when returning the envelope" do
      subject(:data) { response.parsed_body["data"] }

      before { make_request }

      it "returns user, token, and tokenExpiresAt" do
        expect(data["user"]).to include(
          "id" => user.id,
          "email" => user.email,
          "username" => user.username,
          "firstName" => user.first_name,
          "lastName" => user.last_name,
          "emailValidated" => true,
          "roles" => ["member"]
        )
        expect(data["token"]).to be_present
        expect(data["tokenExpiresAt"]).to be_present
      end
    end

    context "when cookie auth is enabled" do
      before do
        CommandTower.configure do |config|
          config.jwt.cookie.enabled = true
        end
      end

      it "sets the auth cookie" do
        make_request
        expect(Array(response.headers["Set-Cookie"]).join).to include("ct_jwt=")
      end
    end
  end

  context "with invalid credentials" do
    let(:user) { create(:user, password: password) }
    let(:params) { { identifier: user.email, password: "wrong-password" } }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }

    it "returns invalid_credentials in the envelope" do
      expect(response.parsed_body["errors"].first).to include(
        "code" => "invalid_credentials",
        "message" => "Invalid credentials"
      )
    end
  end

  context "with blank credentials" do
    let(:params) { { identifier: "", password: "" } }

    before { make_request }

    it { expect(response).to have_http_status(:unauthorized) }

    it "returns invalid_credentials" do
      expect(response.parsed_body["errors"].first["code"]).to eq("invalid_credentials")
    end
  end

  context "when plain-text login is disabled" do
    let(:user) { create(:user, password: password) }
    let(:params) { { identifier: user.email, password: password } }

    before do
      CommandTower.configure do |config|
        config.login.plain_text.enable = false
      end
      make_request
    end

    after do
      CommandTower.configure do |config|
        config.login.plain_text.enable = true
      end
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end

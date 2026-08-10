# frozen_string_literal: true

# Request: POST /auth/password-reset/send HTTP contract.

RSpec.describe "POST /auth/password-reset/send", type: :request do
  let(:path) { "/auth/password-reset/send" }
  let(:client_ip) { "203.0.113.77" }
  let(:session_data) { create_password_recovery_session!(client_ip: client_ip) }
  let(:token) { session_data["recoverySessionToken"] }
  let(:headers) { password_recovery_session_headers(token, client_ip: client_ip) }
  let(:non_enumerating_message) do
    "If an account exists with that email, a password reset link has been sent."
  end

  before do
    flush_password_recovery_rate_limits!
    ActionMailer::Base.deliveries.clear
  end

  context "with a known email" do
    let!(:user) { create(:user, email: "reset-known@example.com", username: "resetknown") }

    before { post path, params: { email: user.email }, headers: headers, as: :json }

    it { expect(response).to have_http_status(:ok) }

    it "returns the non-enumerating success message" do
      expect(response.parsed_body["data"]["message"]).to eq(non_enumerating_message)
    end

    it "sends a reset email" do
      expect(ActionMailer::Base.deliveries.count).to eq(1)
    end
  end

  context "with an unknown email" do
    before { post path, params: { email: "nobody@example.com" }, headers: headers, as: :json }

    it { expect(response).to have_http_status(:ok) }

    it "returns the same non-enumerating success message" do
      expect(response.parsed_body["data"]["message"]).to eq(non_enumerating_message)
    end

    it "does not send an email" do
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  context "without a recovery session" do
    before { post path, params: { email: "reset@example.com" }, as: :json }

    it { expect(response).to have_http_status(:unauthorized) }

    it "returns password_recovery_session_missing" do
      expect(response.parsed_body["errors"].first["code"]).to eq("password_recovery_session_missing")
    end
  end

  context "with a Bearer token instead of Recovery" do
    let!(:user) { create(:user, email: "bearer-reset@example.com", username: "bearerreset") }

    before do
      post path, params: { email: user.email }, headers: authenticate_request_with_bearer!(user), as: :json
    end

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "with a Signup token instead of Recovery" do
    before do
      signup = create_signup_session!
      post path,
        params: { email: "signup-as-recovery@example.com" },
        headers: signup_session_headers(signup["signupSessionToken"]),
        as: :json
    end

    it { expect(response).to have_http_status(:unauthorized) }
  end

  context "without an email" do
    before { post path, headers: headers, as: :json }

    it { expect(response).to have_http_status(:unprocessable_entity) }

    it "names the missing field" do
      expect(response.parsed_body["errors"].first).to include(
        "code" => "validation_failed",
        "details" => { "email" => "Email is required" },
      )
    end
  end

  context "when the jti send budget is exceeded" do
    before do
      CommandTower.config.password_recovery_session.rate_limits.jti_send.times do
        post path, params: { email: "limit@example.com" }, headers: headers, as: :json
        expect(response).to have_http_status(:ok)
      end

      post path, params: { email: "limit@example.com" }, headers: headers, as: :json
    end

    it { expect(response).to have_http_status(:too_many_requests) }

    it "returns password_recovery_session_rate_limited" do
      expect(response.parsed_body["errors"].first["code"]).to eq("password_recovery_session_rate_limited")
    end
  end

  context "when password reset is disabled" do
    before do
      CommandTower.configure do |config|
        config.login.plain_text.password_reset.enabled = false
      end
      post path, params: { email: "reset@example.com" }, as: :json
    end

    after do
      CommandTower.configure do |config|
        config.login.plain_text.password_reset.enabled = true
      end
    end

    it { expect(response).to have_http_status(:not_found) }
  end
end

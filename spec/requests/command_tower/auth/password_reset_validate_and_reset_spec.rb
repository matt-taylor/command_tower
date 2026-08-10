# frozen_string_literal: true

# Request: password-reset validate + reset HTTP contracts.
RSpec.describe "POST /auth/password-reset/validate and /auth/password-reset/reset", type: :request do
  let(:password) { "password1234" }
  let(:new_password) { "newpassword5678" }
  let(:client_ip) { "203.0.113.77" }
  let!(:user) { create(:user, password: password, email: "full-reset@example.com", username: "fullreset") }
  let(:session_data) { create_password_recovery_session!(client_ip: client_ip) }
  let(:headers) { password_recovery_session_headers(session_data["recoverySessionToken"], client_ip: client_ip) }

  before do
    flush_password_recovery_rate_limits!
    ActionMailer::Base.deliveries.clear
  end

  let(:reset_token_for) do
    lambda do |target_user|
      post "/auth/password-reset/send", params: { email: target_user.email }, headers: headers, as: :json
      expect(response).to have_http_status(:ok)

      UserSecret.where(user: target_user, reason: CommandTower::Secrets::PASSWORD_RESET).last.secret
    end
  end

  context "when validating a reset token" do
    let(:token) { reset_token_for.call(user) }

    before do
      post "/auth/password-reset/validate", params: { token: token }, as: :json
    end

    it "validates without a recovery session and without consuming the token" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]).to include("valid" => true)
      expect(response.parsed_body["data"]["expiresAt"]).to be_present
    end

    context "on a second validate call" do
      before { post "/auth/password-reset/validate", params: { token: token }, as: :json }

      it "still accepts the token" do
        expect(response).to have_http_status(:ok)
      end
    end
  end

  context "when resetting the password" do
    let(:token) { reset_token_for.call(user) }

    before do
      post "/auth/password-reset/reset",
        params: { token: token, password: new_password, passwordConfirmation: new_password },
        as: :json
    end

    it "resets the password without issuing a user JWT" do
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"]["message"]).to eq("Password has been successfully reset")
      expect(response.parsed_body["data"]).not_to have_key("token")
      expect(user.reload.authenticate(new_password)).to be_truthy
    end
  end

  context "with an invalid reset token" do
    before { post "/auth/password-reset/validate", params: { token: "not-a-real-token" }, as: :json }

    it "rejects an invalid reset token" do
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["errors"].first["code"]).to eq("password_reset_invalid_token")
    end
  end

  context "when reusing a consumed reset token" do
    let(:token) { reset_token_for.call(user) }

    before do
      post "/auth/password-reset/reset",
        params: { token: token, password: new_password, passwordConfirmation: new_password },
        as: :json
      expect(response).to have_http_status(:ok)

      post "/auth/password-reset/reset",
        params: { token: token, password: "anotherpassword99", passwordConfirmation: "anotherpassword99" },
        as: :json
    end

    it "rejects reuse of a consumed reset token" do
      expect(response).to have_http_status(:unauthorized)
    end
  end

  context "with missing reset fields" do
    before { post "/auth/password-reset/reset", params: {}, as: :json }

    it "names missing reset fields" do
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].first).to include(
        "code" => "validation_failed",
        "details" => {
          "token" => "Token is required",
          "password" => "Password is required",
          "passwordConfirmation" => "Password confirmation is required",
        },
      )
    end
  end
end

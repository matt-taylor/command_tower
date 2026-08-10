# frozen_string_literal: true

RSpec.describe "POST /auth/password-recovery-session", type: :request do
  subject(:make_request) { post path, headers: { "REMOTE_ADDR" => client_ip } }

  let(:path) { "/auth/password-recovery-session" }
  let(:client_ip) { "203.0.113.77" }

  before { flush_password_recovery_rate_limits! }

  context "with a fresh client" do
    before { make_request }

    it { expect(response).to have_http_status(:created) }

    it "returns a recovery session token and expiration" do
      expect(response.parsed_body["data"]["recoverySessionToken"]).to be_present
      expect(response.parsed_body["data"]["expiresAt"]).to be_present
    end

    context "when sending password reset with the issued token" do
      subject(:reset_response) do
        post "/auth/password-reset/send",
             params: { email: "someone@example.com" },
             headers: password_recovery_session_headers(
               response.parsed_body["data"]["recoverySessionToken"],
               client_ip: client_ip,
             ),
             as: :json
        response
      end

      before { reset_response }

      it { expect(reset_response).to have_http_status(:ok) }
    end
  end

  context "when the client ip exceeds the burst ceiling" do
    before do
      CommandTower.config.password_recovery_session.rate_limits.ip_issue_burst.times do
        post path, headers: { "REMOTE_ADDR" => client_ip }
      end
      make_request
    end

    it { expect(response).to have_http_status(:too_many_requests) }

    it "returns password_recovery_ip_rate_limited" do
      expect(response.parsed_body["errors"].first["code"]).to eq("password_recovery_ip_rate_limited")
    end
  end
end

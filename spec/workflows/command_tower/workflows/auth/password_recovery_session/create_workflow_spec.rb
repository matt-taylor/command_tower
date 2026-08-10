# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::PasswordRecoverySession::CreateWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(client_ip: client_ip) }

    let(:client_ip) { "203.0.113.7" }

    before { flush_password_recovery_rate_limits! }

    it { expect(result).to be_success }
    it { expect(result.http_status).to eq(:created) }

    it "returns the serialized recovery session" do
      expect(result.payload[:recoverySessionToken]).to be_present
      expect(result.payload[:expiresAt]).to be_present
    end

    context "when the client ip exceeds the burst ceiling" do
      before do
        CommandTower.config.password_recovery_session.rate_limits.ip_issue_burst.times do
          described_class.call(client_ip: client_ip)
        end
      end

      it "fails with too_many_requests" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoveryIpRateLimitError)
      end
    end

    context "when the session cannot be minted" do
      before do
        allow(CommandTower::Services::Auth::PasswordRecoverySession::Create).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [CommandTower::Errors::InternalError.new])
        )
      end

      it "fails with internal_server_error" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:internal_server_error)
      end
    end
  end
end

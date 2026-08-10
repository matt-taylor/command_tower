# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordRecovery::RateLimits::CheckSend do
  subject(:result) { described_class.call(password_recovery_session: session) }

  let(:limits) { CommandTower.config.password_recovery_session.rate_limits }
  let(:session) { password_recovery_session_context(client_ip: "203.0.113.7") }

  before { flush_password_recovery_rate_limits! }

  describe ".call" do
    it { expect(result).to be_success }

    context "when the session send budget is exhausted" do
      before { limits.jti_send.times { described_class.call(password_recovery_session: session) } }

      it "returns PasswordRecoverySessionRateLimitError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionRateLimitError)
      end
    end

    context "when the session already expired" do
      let(:session) { password_recovery_session_context(expires_at: 1.minute.ago.utc) }

      it "returns PasswordRecoverySessionExpiredError without touching counters" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError)
      end
    end

    context "when the client ip hourly send ceiling is exceeded" do
      before do
        limits.ip_send_hour.times do
          described_class.call(
            password_recovery_session: password_recovery_session_context(client_ip: "203.0.113.7")
          )
        end
      end

      it "returns PasswordRecoveryIpRateLimitError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoveryIpRateLimitError)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::PasswordRecovery::RateLimits::CheckTokenIssue do
  subject(:result) { described_class.call(client_ip: "203.0.113.7") }

  let(:limits) { CommandTower.config.password_recovery_session.rate_limits }

  before { flush_password_recovery_rate_limits! }

  describe ".call" do
    it { expect(result).to be_success }

    context "when the per-minute burst ceiling is exceeded" do
      before { limits.ip_issue_burst.times { described_class.call(client_ip: "203.0.113.7") } }

      it "returns PasswordRecoveryIpRateLimitError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::PasswordRecoveryIpRateLimitError)
      end

      it "advertises a retry window" do
        expect(result.errors.first.details[:retry_after_seconds]).to be_positive
      end
    end

    context "with a different client ip" do
      before { limits.ip_issue_burst.times { described_class.call(client_ip: "203.0.113.7") } }

      it "counts independently" do
        expect(described_class.call(client_ip: "198.51.100.4")).to be_success
      end
    end

    context "without a client ip" do
      subject(:result) { described_class.call }

      it "fails argument validation" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(an_instance_of(CommandTower::Errors::ValidationError))
      end
    end
  end
end

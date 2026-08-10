# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::PasswordRecoverySession::Config do
  subject(:config) { described_class.new }

  describe "claim defaults" do
    # These are wire contract: changing them invalidates recovery tokens already issued.
    it { expect(config.issuer).to eq("command_tower:password-recovery") }
    it { expect(config.audience).to eq("password-recovery-send") }
    it { expect(config.purpose).to eq("password-recovery") }
    it { expect(config.ttl).to eq(15.minutes) }
    it { expect(config.cleanup_buffer_seconds).to eq(300) }
  end

  describe "rate limit defaults" do
    subject(:limits) { config.rate_limits }

    it { expect(limits.jti_send).to eq(5) }
    it { expect(limits.ip_issue_burst).to eq(5) }
    it { expect(limits.ip_issue_hour).to eq(20) }
    it { expect(limits.ip_send_hour).to eq(10) }
  end

  describe "#configured?" do
    it "is true when a signing secret is present" do
      expect(config).to be_configured
    end

    it "is false when the host supplied no secret" do
      config.jwt_secret = ""

      expect(config).not_to be_configured
    end
  end

  describe "engine wiring" do
    it "is reachable as CommandTower.config.password_recovery_session" do
      expect(CommandTower.config.password_recovery_session).to be_a(described_class)
    end
  end
end

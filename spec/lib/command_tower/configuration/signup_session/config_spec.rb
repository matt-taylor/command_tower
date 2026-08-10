# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::SignupSession::Config do
  subject(:config) { described_class.new }

  describe "claim defaults" do
    # These are wire contract: changing them invalidates tokens already issued.
    it { expect(config.issuer).to eq("command_tower:signup") }
    it { expect(config.audience).to eq("signup-availability") }
    it { expect(config.purpose).to eq("signup") }
    it { expect(config.ttl).to eq(20.minutes) }
    it { expect(config.cleanup_buffer_seconds).to eq(300) }
  end

  describe "rate limit defaults" do
    subject(:limits) { config.rate_limits }

    it { expect(limits.jti_email).to eq(50) }
    it { expect(limits.jti_username).to eq(50) }
    it { expect(limits.jti_total).to eq(80) }
    it { expect(limits.ip_issue_burst).to eq(15) }
    it { expect(limits.ip_issue_hour).to eq(60) }
    it { expect(limits.ip_availability_hour).to eq(200) }
    it { expect(limits.ip_register_hour).to eq(20) }
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

  describe "email_availability gate" do
    it "is enabled by default so Engine exposes GET /auth/email/availability" do
      expect(config.email_availability?).to be(true)
      expect(config.email_availability.enable).to be(true)
    end
  end

  describe "engine wiring" do
    it "is reachable as CommandTower.config.signup_session" do
      expect(CommandTower.config.signup_session).to be_a(described_class)
    end
  end
end

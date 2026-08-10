# frozen_string_literal: true

RSpec.describe CommandTower::Configuration::PasswordRecoverySession::RateLimits do
  subject(:limits) { described_class.new }

  it { expect(limits.jti_send).to eq(5) }
  it { expect(limits.ip_issue_burst).to eq(5) }
  it { expect(limits.ip_issue_hour).to eq(20) }
  it { expect(limits.ip_send_hour).to eq(10) }

  describe "host overrides" do
    it "accepts a tighter per-session ceiling" do
      limits.jti_send = 2

      expect(limits.jti_send).to eq(2)
    end
  end
end

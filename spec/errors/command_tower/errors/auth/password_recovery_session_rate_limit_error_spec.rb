# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::PasswordRecoverySessionRateLimitError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("password_recovery_session_rate_limited") }
  it { expect(error.message).to eq("Password recovery session send limit exceeded") }
  it { expect(error.log_level).to eq(:warn) }
  it { expect(error.details).to be_nil }

  context "when a retry window is known" do
    subject(:error) { described_class.new(retry_after_seconds: 42) }

    it { expect(error.details).to eq(retry_after_seconds: 42) }
  end
end

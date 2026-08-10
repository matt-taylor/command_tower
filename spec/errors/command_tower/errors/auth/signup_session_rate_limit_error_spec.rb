# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SignupSessionRateLimitError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("signup_session_rate_limited") }
  it { expect(error.message).to eq("Signup session lookup limit exceeded") }
  it { expect(error.log_level).to eq(:warn) }
  it { expect(error.details).to be_nil }

  context "when a retry window is known" do
    subject(:error) { described_class.new(retry_after_seconds: 42) }

    it { expect(error.details).to eq(retry_after_seconds: 42) }
  end
end

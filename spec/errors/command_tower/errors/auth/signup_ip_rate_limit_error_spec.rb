# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SignupIpRateLimitError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("signup_ip_rate_limited") }
  it { expect(error.message).to eq("Too many signup requests from this network") }
  it { expect(error.log_level).to eq(:warn) }
  it { expect(error.details).to be_nil }

  context "when a retry window is known" do
    subject(:error) { described_class.new(retry_after_seconds: 90) }

    it { expect(error.details).to eq(retry_after_seconds: 90) }
  end
end

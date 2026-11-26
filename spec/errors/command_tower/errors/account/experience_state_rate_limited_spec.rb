# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Account::ExperienceStateRateLimited do
  subject(:error) { described_class.new(retry_after_seconds: 12) }

  it { expect(error.code).to eq("experience_state_rate_limited") }
  it { expect(error.log_level).to eq(:warn) }
  it { expect(error.message).to eq("Too many requests. Please try again later.") }
  it { expect(error.details).to eq({ retry_after_seconds: 12 }) }
  it { expect(described_class.new.details).to be_nil }
end

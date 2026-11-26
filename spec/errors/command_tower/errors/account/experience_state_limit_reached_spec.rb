# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Account::ExperienceStateLimitReached do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("experience_state_limit_reached") }
  it { expect(error.log_level).to eq(:warn) }
  it { expect(error.message).to eq("Experience state limit reached") }

  it "never echoes submitted input" do
    expect(error.message).not_to match(/welcome|:|\d/)
  end
end

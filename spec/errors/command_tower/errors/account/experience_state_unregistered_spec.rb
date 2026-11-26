# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Account::ExperienceStateUnregistered do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("experience_state_unregistered") }
  it { expect(error.log_level).to eq(:warn) }
  it { expect(error.message).to eq("Experience state is not registered") }

  it "never echoes submitted input" do
    expect(error.message).not_to match(/welcome|:/)
  end
end

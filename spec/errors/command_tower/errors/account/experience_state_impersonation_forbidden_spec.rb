# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Account::ExperienceStateImpersonationForbidden do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::ForbiddenError) }
  it { expect(error.code).to eq("experience_state_impersonation_forbidden") }
  it { expect(error.message).to eq("Experience states cannot be changed while impersonating") }
  it { expect(error.log_level).to eq(:warn) }
end

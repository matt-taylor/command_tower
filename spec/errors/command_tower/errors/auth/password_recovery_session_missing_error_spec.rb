# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::PasswordRecoverySessionMissingError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("password_recovery_session_missing") }
  it { expect(error.message).to eq("Password recovery session is required") }
  it { expect(error.log_level).to eq(:warn) }
end

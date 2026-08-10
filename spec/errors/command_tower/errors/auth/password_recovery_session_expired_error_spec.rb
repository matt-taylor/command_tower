# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("password_recovery_session_expired") }
  it { expect(error.message).to eq("Password recovery session has expired") }
  it { expect(error.log_level).to eq(:warn) }
end

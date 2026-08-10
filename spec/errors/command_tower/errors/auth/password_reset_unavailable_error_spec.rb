# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::PasswordResetUnavailableError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("password_reset_unavailable") }
  it { expect(error.message).to eq("Password reset is currently unavailable") }
  it { expect(error.log_level).to eq(:warn) }
end

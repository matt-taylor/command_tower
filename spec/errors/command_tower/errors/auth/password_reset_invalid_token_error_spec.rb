# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::PasswordResetInvalidTokenError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("password_reset_invalid_token") }
  it { expect(error.message).to eq("Invalid token") }
  it { expect(error.log_level).to eq(:warn) }
end

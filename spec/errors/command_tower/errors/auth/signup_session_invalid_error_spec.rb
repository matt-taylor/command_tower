# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SignupSessionInvalidError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("signup_session_invalid") }
  it { expect(error.message).to eq("Signup session token is invalid") }
end

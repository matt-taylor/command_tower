# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SignupSessionMissingError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("signup_session_missing") }
  it { expect(error.message).to eq("Signup session token is required") }
end

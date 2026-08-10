# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SignupSessionExpiredError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("signup_session_expired") }
  it { expect(error.message).to eq("Signup session token has expired") }
end

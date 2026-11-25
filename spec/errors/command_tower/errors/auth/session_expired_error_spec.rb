# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SessionExpiredError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("session_expired") }
  it { expect(error.message).to eq("Your session has expired. Please sign in again.") }
end

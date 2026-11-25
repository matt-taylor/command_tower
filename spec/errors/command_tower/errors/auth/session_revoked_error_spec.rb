# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::SessionRevokedError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("session_revoked") }
  it { expect(error.message).to eq("Your session has ended. Please sign in again.") }
end

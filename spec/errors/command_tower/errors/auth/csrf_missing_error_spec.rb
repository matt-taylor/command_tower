# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::CsrfMissingError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("csrf_missing") }
  it { expect(error.message).to eq("CSRF token missing") }
end

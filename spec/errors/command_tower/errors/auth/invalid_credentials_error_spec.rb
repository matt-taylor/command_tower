# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::InvalidCredentialsError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("invalid_credentials") }
  it { expect(error.message).to eq("Invalid credentials") }
  it { expect(error.log_level).to eq(:info) }
end

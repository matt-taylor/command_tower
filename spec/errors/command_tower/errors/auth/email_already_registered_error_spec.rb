# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::EmailAlreadyRegisteredError do
  subject(:error) { described_class.new(details: { email: "has already been taken" }) }

  it { expect(error).to be_a(CommandTower::Errors::ValidationError) }
  it { expect(error.code).to eq("email_already_registered") }
  it { expect(error.message).to eq("Email is already registered") }
  it { expect(error.details).to eq(email: "has already been taken") }
end

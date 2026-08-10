# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::EmailVerificationRequiredError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::UnauthorizedError) }
  it { expect(error.code).to eq("email_verification_required") }
  it { expect(error.message).to eq("Email verification required") }
  it { expect(error.log_level).to eq(:info) }
end

# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::VerificationCodeInvalidError do
  subject(:error) { described_class.new }

  it { expect(error).to be_a(CommandTower::Errors::ValidationError) }
  it { expect(error.code).to eq("verification_code_invalid") }
  it { expect(error.message).to eq("Verification code is invalid") }

  context "with field details" do
    subject(:error) { described_class.new(details: { code: "Incorrect verification code provided" }) }

    it { expect(error.details).to eq(code: "Incorrect verification code provided") }
  end
end

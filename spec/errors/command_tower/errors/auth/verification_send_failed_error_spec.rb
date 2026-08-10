# frozen_string_literal: true

RSpec.describe CommandTower::Errors::Auth::VerificationSendFailedError do
  subject(:error) { described_class.new }

  it { expect(error.code).to eq("verification_send_failed") }
  it { expect(error.message).to eq("Unable to send verification email") }
  it { expect(error.log_level).to eq(:error) }
  it { expect(error).to be_retryable }
end

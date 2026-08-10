# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Auth::EmailVerification::SendWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user) }

    context "when a code is sent" do
      let(:user) { create(:user, :unvalidated_email) }

      before do
        allow(CommandTower::EmailVerificationMailer).to receive(:verify_email).and_return(
          instance_double(Mail::Message, deliver: true)
        )
      end

      it { expect(result).to be_success }
      it { expect(result.http_status).to eq(:created) }

      it "serializes the message" do
        expect(result.payload).to eq(message: "Successfully sent email verification code")
      end
    end

    context "when the email is already verified" do
      let(:user) { create(:user) }

      it "is idempotent with ok rather than created" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:message]).to include("already verified")
      end
    end

    context "when delivery fails" do
      let(:user) { create(:user, :unvalidated_email) }

      before do
        allow(CommandTower::EmailVerificationMailer).to receive(:verify_email).and_raise(StandardError, "smtp down")
      end

      it "fails with bad_gateway" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:bad_gateway)
        expect(result.errors.first).to be_a(CommandTower::Errors::Auth::VerificationSendFailedError)
      end
    end
  end
end

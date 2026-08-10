# frozen_string_literal: true

RSpec.describe CommandTower::Services::Auth::EmailVerification::Send do
  describe ".call" do
    subject(:result) { described_class.call(user: user) }

    context "when the user is not yet verified" do
      let(:user) { create(:user, :unvalidated_email) }

      before do
        allow(CommandTower::EmailVerificationMailer).to receive(:verify_email).and_return(
          instance_double(Mail::Message, deliver: true)
        )
      end

      it { expect(result).to be_success }

      it "reports the code was sent" do
        expect(result.data[:message]).to eq("Successfully sent email verification code")
      end
    end

    context "when the user is already verified" do
      let(:user) { create(:user) }

      it "short circuits without generating a secret" do
        expect(CommandTower::Secrets::Generate).not_to receive(:call)

        expect(result).to be_success
        expect(result.data[:message]).to eq("Email is already verified. No code required")
      end
    end

    context "when delivery fails" do
      let(:user) { create(:user, :unvalidated_email) }

      before do
        allow(CommandTower::EmailVerificationMailer).to receive(:verify_email).and_raise(StandardError, "smtp down")
      end

      it "returns VerificationSendFailedError" do
        expect(result).to be_failure
        expect(result.errors).to contain_exactly(
          an_instance_of(CommandTower::Errors::Auth::VerificationSendFailedError)
        )
      end
    end
  end
end

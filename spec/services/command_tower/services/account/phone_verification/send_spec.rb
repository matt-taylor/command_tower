# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::PhoneVerification::Send do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: false) }
    let(:fake_adapter) { CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter }

    before do
      CommandTower::Identity::PhoneVerification::SmsTransport.reset_adapter!
      fake_adapter.reset!
      allow(CommandTower.config.identity.phone_verification).to receive(:sms_adapter).and_return("fake")
      allow(CommandTower.config.identity.phone_verification).to receive(:resend_cooldown).and_return(30.seconds)
    end

    it "delivers an OTP without returning the code to callers" do
      expect(result).to be_success
      expect(result.data[:code_length]).to eq(6)
      expect(result.data[:phone_number]).to eq("+14155552671")
      expect(result.data[:expires_at]).to be_present
      expect(result.data[:resend_available_at]).to be_present

      delivery = fake_adapter.deliveries.last
      expect(delivery[:to]).to eq("+14155552671")
      expect(delivery[:body]).to match(/verification code is \d{6}/)
    end

    it "binds the issued challenge to the current phone" do
      result

      challenge = UserSecret.find_by!(user:, reason: CommandTower::Secrets::PHONE_VERIFICATION)
      expect(challenge.extra).to eq("+14155552671")
      expect(challenge.secret).to match(/\A\d{6}\z/)
    end

    context "when a code was issued moments ago" do
      before { expect(described_class.call(user:)).to be_success }

      it "returns PhoneVerificationThrottledError carrying the retry time" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationThrottledError)
        expect(result.errors.first.resend_available_at).to be_present
      end
    end

    context "when the user has no phone" do
      let(:user) { create(:user, :without_phone) }

      it "returns PhoneMissingError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneMissingError)
      end
    end

    context "when the phone is already verified" do
      let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: true) }

      it "returns PhoneAlreadyVerifiedError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneAlreadyVerifiedError)
      end
    end

    context "when the SMS provider rejects the delivery" do
      before { fake_adapter.fail_with = [:provider_unavailable, "down"] }

      it "returns PhoneVerificationSendFailedError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationSendFailedError)
      end
    end

    context "when phone verification is disabled" do
      before do
        allow(CommandTower.config.identity.phone_verification).to receive(:enable).and_return(false)
      end

      it "returns PhoneVerificationSendFailedError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationSendFailedError)
      end

      it "does not deliver anything" do
        result

        expect(fake_adapter.deliveries).to be_empty
      end
    end
  end
end

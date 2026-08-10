# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::PhoneVerification::SendWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user, auth_context: auth_context) }

    let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: false, roles: ["member"]) }
    let(:auth_context) do
      CommandTower::Auth::AuthContext.new(
        user: user,
        token_expires_at: 1.hour.from_now.iso8601,
        token_source: :header,
        roles: user.roles,
        principal_type: :user,
        generated_token: nil
      )
    end
    let(:fake_adapter) { CommandTower::Identity::PhoneVerification::SmsTransport::Adapters::FakeAdapter }

    before do
      allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(true)
      CommandTower::Identity::PhoneVerification::SmsTransport.reset_adapter!
      fake_adapter.reset!
      allow(CommandTower.config.identity.phone_verification).to receive(:sms_adapter).and_return("fake")
      allow(CommandTower.config.identity.phone_verification).to receive(:resend_cooldown).and_return(0.seconds)
    end

    context "when sending a verification code succeeds" do
      it "returns verification metadata without leaking the OTP" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:codeLength]).to eq(6)
        expect(result.payload[:phoneNumber]).to eq("+14155552671")
        expect(result.payload[:expiresAt]).to be_present
        expect(result.payload[:resendAvailableAt]).to be_present
        expect(result.payload.values.join).not_to match(/\b\d{6}\b/)
        expect(result.response_effects[:set_expire_header]).to eq(auth_context.token_expires_at)
      end
    end

    context "when the SMS product gate is off" do
      before do
        allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(false)
      end

      it "returns service_unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::SmsCapabilityUnavailableError)
      end
    end

    context "when resend is throttled" do
      before do
        allow(CommandTower.config.identity.phone_verification).to receive(:resend_cooldown).and_return(30.seconds)
        expect(CommandTower::Services::Account::PhoneVerification::Send.call(user:)).to be_success
      end

      it "returns too_many_requests with resend metadata" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:too_many_requests)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationThrottledError)
        expect(result.meta[:resendAvailableAt]).to be_present
      end
    end
  end
end

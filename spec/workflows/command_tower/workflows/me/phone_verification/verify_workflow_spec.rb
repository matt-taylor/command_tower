# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::PhoneVerification::VerifyWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user, code: code, auth_context: auth_context) }

    let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: false, roles: ["member"]) }
    let(:code) { "000000" }
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
      allow(CommandTower::Messaging::Execution::Adapters::Sms::Configuration)
        .to receive(:sms_configured?).and_return(false)
      allow(CommandTower::Identity::PhoneVerification::SmsConfiguration)
        .to receive(:sms_ready?).and_return(false)
      allow(CommandTower::Messaging::Execution::Adapters::Pushover::Configuration)
        .to receive(:pushover_configured?).and_return(false)
    end

    context "when verifying a valid code succeeds" do
      let(:code) do
        expect(CommandTower::Services::Account::PhoneVerification::Send.call(user:)).to be_success
        fake_adapter.deliveries.last[:body][/\d{6}/]
      end

      before { code }

      it "returns the account payload with the phone validated" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:id]).to eq(user.id)
        expect(result.payload[:phoneNumberValidated]).to eq(true)
        expect(user.reload.phone_number_validated).to eq(true)
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

    context "when the verification code is invalid" do
      before do
        expect(CommandTower::Services::Account::PhoneVerification::Send.call(user:)).to be_success
      end

      it "returns unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PhoneVerificationCodeInvalidError)
      end
    end
  end
end

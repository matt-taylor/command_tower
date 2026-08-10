# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::UpdatePhoneWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: user,
        phone_number: phone_number,
        auth_context: auth_context
      )
    end

    let(:user) { create(:user, :without_phone, roles: ["member"]) }
    let(:phone_number) { "4155552671" }
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

    before do
      allow(CommandTower::Services::Me::SmsProductGate).to receive(:enabled?).and_return(true)
      allow(CommandTower::Messaging::Execution::Adapters::Sms::Configuration)
        .to receive(:sms_configured?).and_return(false)
      allow(CommandTower::Identity::PhoneVerification::SmsConfiguration)
        .to receive(:sms_ready?).and_return(false)
      allow(CommandTower::Messaging::Execution::Adapters::Pushover::Configuration)
        .to receive(:pushover_configured?).and_return(false)
    end

    context "when the phone update succeeds" do
      it "returns the account payload with the normalized phone number" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:id]).to eq(user.id)
        expect(result.payload[:phoneNumber]).to eq("+14155552671")
        expect(result.payload[:phoneNumberValidated]).to eq(false)
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

    context "when the phone number is invalid" do
      let(:phone_number) { "nope" }

      it "returns unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ClearPhoneWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user, auth_context: auth_context) }

    let(:user) { create(:user, phone_number: "+14155552671", phone_number_validated: true, roles: ["member"]) }
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

    context "when clearing the phone succeeds" do
      it "returns the account payload with the phone cleared" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:id]).to eq(user.id)
        expect(result.payload[:phoneNumber]).to be_nil
        expect(user.reload.phone_number).to be_nil
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

    context "when clearing the phone fails" do
      let(:internal_error) { CommandTower::Errors::InternalError.new }

      before do
        allow(CommandTower::Services::Account::ClearPhone).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [internal_error])
        )
      end

      it "returns internal_server_error" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:internal_server_error)
        expect(result.errors.first).to eq(internal_error)
      end
    end
  end
end

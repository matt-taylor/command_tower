# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::UpdateNameWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: user,
        first_name: first_name,
        last_name: last_name,
        auth_context: auth_context
      )
    end

    let(:user) { create(:user, first_name: "Old", last_name: "Name", roles: ["member"]) }
    let(:first_name) { "New" }
    let(:last_name) { "Person" }
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
      allow(CommandTower::Messaging::Execution::Adapters::Sms::Configuration)
        .to receive(:sms_configured?).and_return(false)
      allow(CommandTower::Identity::PhoneVerification::SmsConfiguration)
        .to receive(:sms_ready?).and_return(false)
      allow(CommandTower::Messaging::Execution::Adapters::Pushover::Configuration)
        .to receive(:pushover_configured?).and_return(false)
    end

    context "when the name update succeeds" do
      it "returns the account payload with expire effect" do
        expect(result).to be_success
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:id]).to eq(user.id)
        expect(result.payload[:firstName]).to eq("New")
        expect(result.payload[:lastName]).to eq("Person")
        expect(result.response_effects[:set_expire_header]).to eq(auth_context.token_expires_at)
      end
    end

    context "when the name update fails" do
      let(:validation_error) do
        CommandTower::Errors::ValidationError.new(details: { firstName: "is invalid" })
      end

      before do
        allow(CommandTower::Services::Me::UpdateName).to receive(:call).and_return(
          CommandTower::Services::ServiceResult.failure(errors: [validation_error])
        )
      end

      it "returns unprocessable_entity" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to eq(validation_error)
      end
    end
  end
end

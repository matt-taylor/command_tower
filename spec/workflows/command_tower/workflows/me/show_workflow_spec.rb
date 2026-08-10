# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::ShowWorkflow do
  describe ".call" do
    subject(:result) { described_class.call(current_user: user, auth_context: auth_context) }

    let(:user) { create(:user, roles: ["member"]) }
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

    it "returns the account payload with expire effect" do
      expect(result).to be_success
      expect(result.payload[:id]).to eq(user.id)
      expect(result.payload[:capabilities]).to be_present
      expect(result.response_effects[:set_expire_header]).to be_present
    end
  end
end

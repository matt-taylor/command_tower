# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::Push::CreateWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: user,
        address:,
        auth_context:,
      )
    end

    let(:user) { create(:user, roles: ["member"]) }
    let(:address) { "ExponentPushToken[wfcreate01]" }
    let(:auth_context) do
      CommandTower::Auth::AuthContext.new(
        user:,
        token_expires_at: 1.hour.from_now.iso8601,
        token_source: :header,
        roles: user.roles,
        principal_type: :user,
        generated_token: nil,
      )
    end

    before do
      allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(true)
    end

    context "when push product gate is off" do
      before do
        allow(CommandTower::Services::Me::PushProductGate).to receive(:enabled?).and_return(false)
      end

      it "returns capability unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushCapabilityUnavailableError)
        expect(result.errors.first.code).to eq("push_capability_unavailable")
      end
    end

    context "when create succeeds" do
      it { expect(result).to be_success }

      it "returns a verified endpoint payload without the token" do
        expect(result.payload[:verificationState]).to eq("verified")
        expect(result.payload[:channelKey]).to eq("push")
        expect(result.payload.to_json).not_to include("ExponentPushToken")
        expect(result.response_effects[:set_expire_header]).to be_present
      end
    end
  end
end

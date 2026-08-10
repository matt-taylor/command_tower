# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::Pushover::ShowWorkflow do
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
      allow(CommandTower::Services::Me::PushoverProductGate).to receive(:enabled?).and_return(true)
    end

    context "when Pushover product gate is off" do
      before do
        allow(CommandTower::Services::Me::PushoverProductGate).to receive(:enabled?).and_return(false)
      end

      it "returns capability unavailable" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:service_unavailable)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushoverCapabilityUnavailableError)
      end
    end

    context "when pushover is not configured" do
      it { expect(result).to be_success }

      it "returns unconfigured payload" do
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:configured]).to eq(false)
        expect(result.payload[:actions]).to eq(
          canCreate: true,
          canVerify: false,
          canReplace: false,
          canRemove: false
        )
      end

      it "includes expire header effect" do
        expect(result.response_effects[:set_expire_header]).to be_present
      end
    end

    context "when pushover is configured" do
      before do
        CommandTower::Services::Account::Pushover::Create.call(
          user:,
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz"
        )
      end

      it { expect(result).to be_success }

      it "returns configured payload without secrets" do
        expect(result.payload[:configured]).to eq(true)
        expect(result.payload[:channelKey]).to eq("pushover")
        expect(result.payload[:verificationState]).to eq("unverified")
        expect(result.payload.to_json).not_to include("pushover-user-key-abcd")
        expect(result.payload.to_json).not_to include("pushover-app-token-zzzz")
      end
    end
  end
end

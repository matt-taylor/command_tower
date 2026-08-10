# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::Pushover::ReplaceWorkflow do
  describe ".call" do
    subject(:result) do
      described_class.call(
        current_user: user,
        user_key:,
        application_token:,
        auth_context: auth_context
      )
    end

    let(:user) { create(:user, roles: ["member"]) }
    let(:user_key) { "pushover-user-key-efgh" }
    let(:application_token) { "pushover-app-token-yyyy" }
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

    context "when replacing existing credentials" do
      around do |example|
        previous = CommandTower.config.messaging.pushover.adapter
        CommandTower.config.messaging.pushover.adapter = "fake"
        CommandTower::Messaging::Pushover::Transport.reset_adapter!
        CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
        example.run
      ensure
        CommandTower.config.messaging.pushover.adapter = previous
        CommandTower::Messaging::Pushover::Transport.reset_adapter!
        CommandTower::Messaging::Pushover::Adapters::FakeAdapter.reset!
      end

      before do
        CommandTower::Services::Account::Pushover::Create.call(
          user:,
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz"
        )
      end

      it { expect(result).to be_success }

      it "returns a new unverified payload without secrets" do
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:configured]).to eq(true)
        expect(result.payload[:verificationState]).to eq("unverified")
        expect(result.payload.to_json).not_to include("pushover-user-key-efgh")
        expect(result.payload.to_json).not_to include("pushover-app-token-yyyy")
      end

      it "includes expire header effect" do
        expect(result.response_effects[:set_expire_header]).to be_present
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe CommandTower::Workflows::Me::Pushover::VerifyWorkflow do
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
      it "returns not configured failure" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushoverNotConfiguredError)
      end
    end

    context "when verification succeeds" do
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

      it "returns verified payload without secrets" do
        expect(result.http_status).to eq(:ok)
        expect(result.payload[:verificationState]).to eq("verified")
        expect(result.payload.to_json).not_to include("pushover-user-key-abcd")
        expect(result.payload.to_json).not_to include("pushover-app-token-zzzz")
      end

      it "includes expire header effect" do
        expect(result.response_effects[:set_expire_header]).to be_present
      end
    end

    context "when Pushover rejects the user key" do
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
        CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_user
      end

      it "maps invalid_user verification failure" do
        expect(result).to be_failure
        expect(result.http_status).to eq(:unprocessable_entity)
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushoverVerificationFailedError)
        expect(result.errors.first.code).to eq("pushover_invalid_user")
      end
    end
  end
end

# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Pushover::Verify do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }

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

    context "when pushover is not configured" do
      it "returns PushoverNotConfiguredError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushoverNotConfiguredError)
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

      it "returns a verified safe view" do
        expect(result.data[:safe_view].verification_state).to eq("verified")
        expect(result.data[:safe_view].verified_at).to be_present
      end
    end

    context "when Pushover rejects the user key" do
      before do
        CommandTower::Services::Account::Pushover::Create.call(
          user:,
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz"
        )
        CommandTower::Messaging::Pushover::Adapters::FakeAdapter.fail_with = :invalid_user
      end

      it "returns PushoverVerificationFailedError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushoverVerificationFailedError)
        expect(result.errors.first.code).to eq("pushover_invalid_user")
      end
    end
  end
end

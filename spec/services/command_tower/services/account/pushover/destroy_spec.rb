# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Pushover::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }

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

      it "returns a revoked safe view" do
        expect(result.data[:safe_view].lifecycle_state).to eq("revoked")
        expect(result.data[:safe_view].revoked_at).to be_present
      end
    end
  end
end

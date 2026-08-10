# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Pushover::Create do
  describe ".call" do
    subject(:result) { described_class.call(user:, user_key:, application_token:) }

    let(:user) { create(:user) }
    let(:user_key) { "pushover-user-key-abcd" }
    let(:application_token) { "pushover-app-token-zzzz" }

    context "when credentials are valid" do
      it { expect(result).to be_success }

      it "creates a pushover endpoint safe view" do
        expect(result.data[:safe_view]).to be_present
        expect(result.data[:safe_view].channel_key).to eq("pushover")
        expect(result.data[:safe_view].lifecycle_state).to eq("active")
        expect(result.data[:safe_view].verification_state).to eq("unverified")
        expect(result.data[:safe_view].credentials_configured).to be(true)
      end
    end

    context "when pushover is already configured with different credentials" do
      before do
        described_class.call(
          user:,
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz"
        )
      end

      let(:user_key) { "pushover-user-key-efgh" }
      let(:application_token) { "pushover-app-token-yyyy" }

      it "returns PushoverAlreadyConfiguredError" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushoverAlreadyConfiguredError)
      end
    end

    context "when user_key is blank" do
      let(:user_key) { "" }

      it "returns a validation error" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end

    context "when application_token is blank" do
      let(:application_token) { "" }

      it "returns a validation error" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end
  end
end

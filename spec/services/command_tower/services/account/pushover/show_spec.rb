# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Pushover::Show do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }

    context "when no pushover endpoint exists" do
      it { expect(result).to be_success }

      it "returns a nil safe view" do
        expect(result.data[:safe_view]).to be_nil
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

      it "returns the active endpoint safe view" do
        expect(result.data[:safe_view]).to be_present
        expect(result.data[:safe_view].channel_key).to eq("pushover")
        expect(result.data[:safe_view].lifecycle_state).to eq("active")
        expect(result.data[:safe_view].credentials_configured).to be(true)
      end
    end
  end
end

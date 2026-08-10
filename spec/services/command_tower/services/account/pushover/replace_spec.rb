# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Pushover::Replace do
  describe ".call" do
    subject(:result) { described_class.call(user:, user_key:, application_token:) }

    let(:user) { create(:user) }
    let(:user_key) { "pushover-user-key-efgh" }
    let(:application_token) { "pushover-app-token-yyyy" }

    context "when replacing existing credentials" do
      before do
        CommandTower::Services::Account::Pushover::Create.call(
          user:,
          user_key: "pushover-user-key-abcd",
          application_token: "pushover-app-token-zzzz"
        )
      end

      it { expect(result).to be_success }

      it "returns a new unverified endpoint with updated masked display" do
        expect(result.data[:safe_view].verification_state).to eq("unverified")
        expect(result.data[:safe_view].lifecycle_state).to eq("active")
        expect(result.data[:safe_view].masked_display_value).to eq("#{"•" * 8}efgh")
        expect(result.data[:safe_view].credentials_configured).to be(true)
      end
    end
  end
end

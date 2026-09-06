# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Push::Create do
  describe ".call" do
    subject(:result) { described_class.call(user:, address:) }

    let(:user) { create(:user) }
    let(:address) { "ExponentPushToken[create1111]" }

    context "when the token is valid" do
      it { expect(result).to be_success }

      it "creates a verified active push endpoint" do
        expect(result.data[:safe_view].channel_key).to eq("push")
        expect(result.data[:safe_view].lifecycle_state).to eq("active")
        expect(result.data[:safe_view].verification_state).to eq("verified")
        expect(result.data[:safe_view].verified_at).to be_present
      end
    end

    context "when the same token is posted again" do
      before { described_class.call(user:, address:) }

      it "returns the existing verified endpoint without error" do
        expect(result).to be_success
        expect(result.data[:safe_view].verification_state).to eq("verified")
        expect(
          CommandTower::Messaging::Endpoint.for_owner(user.id).where(channel_key: "push").count,
        ).to eq(1)
      end
    end

    context "when the token is not Expo form" do
      let(:address) { "not-an-expo-token-value" }

      it "returns a validation error" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::ValidationError)
      end
    end
  end
end

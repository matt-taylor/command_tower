# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Push::Replace do
  describe ".call" do
    subject(:result) { described_class.call(user:, endpoint_id: original.id, address:) }

    let(:user) { create(:user) }
    let(:original) do
      view = CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "push",
        address: "ExponentPushToken[replaceold]",
      )
      CommandTower::Messaging::Endpoints.mark_verified(owner_user_id: user.id, endpoint_id: view.id)
    end
    let(:address) { "ExponentPushToken[replacenew]" }

    it "retires the prior row and returns a verified replacement" do
      expect(result).to be_success
      expect(result.data[:safe_view].id).not_to eq(original.id)
      expect(result.data[:safe_view].verification_state).to eq("verified")
      expect(original.id).to be_present
      expect(
        CommandTower::Messaging::Endpoint.find(original.id).lifecycle_state,
      ).to eq("retired")
    end
  end
end

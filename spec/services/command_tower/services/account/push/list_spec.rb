# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Push::List do
  describe ".call" do
    subject(:result) { described_class.call(user:) }

    let(:user) { create(:user) }

    context "when active and revoked endpoints exist" do
      let!(:active) do
        view = CommandTower::Messaging::Endpoints.create(
          owner_user_id: user.id,
          channel_key: "push",
          address: "ExponentPushToken[listaaaa]",
        )
        CommandTower::Messaging::Endpoints.mark_verified(owner_user_id: user.id, endpoint_id: view.id)
      end

      before do
        revoked = CommandTower::Messaging::Endpoints.create(
          owner_user_id: user.id,
          channel_key: "push",
          address: "ExponentPushToken[listbbbb]",
        )
        CommandTower::Messaging::Endpoints.revoke(owner_user_id: user.id, endpoint_id: revoked.id)
      end

      it "returns only active endpoints" do
        expect(result).to be_success
        expect(result.data[:safe_views].map(&:id)).to eq([active.id])
      end
    end

    context "when no endpoints exist" do
      it "returns an empty collection" do
        expect(result).to be_success
        expect(result.data[:safe_views]).to eq([])
      end
    end
  end
end

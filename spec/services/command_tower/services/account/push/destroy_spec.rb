# frozen_string_literal: true

RSpec.describe CommandTower::Services::Account::Push::Destroy do
  describe ".call" do
    subject(:result) { described_class.call(user:, endpoint_id: endpoint.id) }

    let(:user) { create(:user) }
    let(:endpoint) do
      view = CommandTower::Messaging::Endpoints.create(
        owner_user_id: user.id,
        channel_key: "push",
        address: "ExponentPushToken[destroy01]",
      )
      CommandTower::Messaging::Endpoints.mark_verified(owner_user_id: user.id, endpoint_id: view.id)
    end

    it "revokes the endpoint" do
      expect(result).to be_success
      expect(result.data[:safe_view].lifecycle_state).to eq("revoked")
    end

    context "when the endpoint is missing" do
      subject(:result) { described_class.call(user:, endpoint_id: 0) }

      it "maps not found" do
        expect(result).to be_failure
        expect(result.errors.first).to be_a(CommandTower::Errors::Account::PushEndpointNotFoundError)
      end
    end
  end
end

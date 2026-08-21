# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Impersonation::SessionSerializer do
  describe ".serialize" do
    subject(:payload) { described_class.serialize(session) }

    let(:session) { create(:impersonation_session) }

    it "projects session identifiers and clocks" do
      expect(payload).to include(
        :id,
        :actorUserId,
        :targetUserId,
        :idleExpiresAt,
        :absoluteExpiresAt
      )
      expect(payload[:id]).to eq(session.id)
      expect(payload[:actorUserId]).to eq(session.actor_user_id)
      expect(payload[:targetUserId]).to eq(session.target_user_id)
    end
  end
end

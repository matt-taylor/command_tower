# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::SessionResponseSerializer do
  describe ".serialize" do
    let(:user) { create(:user, first_name: "Pat", last_name: "Target") }

    it "omits impersonation without a session" do
      payload = described_class.serialize(user:, token_expires_at: 1.hour.from_now.iso8601)
      expect(payload).not_to have_key(:impersonation)
      expect(payload[:user][:id]).to eq(user.id)
    end

    it "projects impersonation identity and clocks" do
      actor = create(:user, first_name: "Ada", last_name: "Admin")
      session = create(:impersonation_session, actor:, target: user)
      payload = described_class.serialize(
        user:,
        token_expires_at: 1.hour.from_now.iso8601,
        impersonation_session: session,
        actor:
      )

      expect(payload[:impersonation]).to include(
        active: true,
        sessionId: session.id,
        actorUserId: actor.id,
        actorDisplayName: "Ada Admin",
        targetUserId: user.id
      )
      expect(payload[:impersonation][:idleExpiresAt]).to be_present
      expect(payload[:impersonation][:absoluteExpiresAt]).to be_present
    end
  end
end

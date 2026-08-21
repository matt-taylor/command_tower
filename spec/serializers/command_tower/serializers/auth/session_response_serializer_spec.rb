# frozen_string_literal: true

RSpec.describe CommandTower::Serializers::Auth::SessionResponseSerializer do
  describe ".serialize" do
    let(:user) { create(:user, first_name: "Pat", last_name: "Target") }
    let(:token_expires_at) { 1.hour.from_now.iso8601 }

    context "when there is no impersonation session" do
      subject(:payload) { described_class.serialize(user:, token_expires_at:) }

      it "omits impersonation" do
        expect(payload).not_to have_key(:impersonation)
      end

      it "includes the user id" do
        expect(payload[:user][:id]).to eq(user.id)
      end
    end

    context "when an impersonation session is present" do
      let(:actor) { create(:user, first_name: "Ada", last_name: "Admin") }
      let!(:session) { create(:impersonation_session, actor:, target: user) }

      subject(:payload) do
        described_class.serialize(
          user:,
          token_expires_at:,
          impersonation_session: session,
          actor:
        )
      end

      it "projects impersonation identity" do
        expect(payload[:impersonation]).to include(
          active: true,
          sessionId: session.id,
          actorUserId: actor.id,
          actorDisplayName: "Ada Admin",
          targetUserId: user.id
        )
      end

      it "projects impersonation clocks" do
        expect(payload[:impersonation][:idleExpiresAt]).to be_present
        expect(payload[:impersonation][:absoluteExpiresAt]).to be_present
      end
    end
  end
end

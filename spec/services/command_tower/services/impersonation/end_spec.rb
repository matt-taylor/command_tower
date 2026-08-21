# frozen_string_literal: true

RSpec.describe CommandTower::Services::Impersonation::End do
  describe ".call" do
    subject(:result) { described_class.call(session_id: session.id, reason: "manual", actor_user_id: actor.id) }

    let(:actor) { create(:user) }
    let(:target) { create(:user) }
    let!(:session) { create(:impersonation_session, actor:, target:) }

    it "ends the open session once" do
      expect(result).to be_success
      expect(result.data[:ended]).to be(true)
      expect(session.reload.end_reason).to eq("manual")
      expect(session.ended_at).to be_present
    end

    context "when the session is already ended" do
      before { described_class.call(session_id: session.id, reason: "idle_timeout", actor_user_id: actor.id) }

      it "does not treat the second end as a new close" do
        expect(result.data[:ended]).to be(false)
        expect(session.reload.end_reason).to eq("idle_timeout")
      end
    end
  end
end

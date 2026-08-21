# frozen_string_literal: true

RSpec.describe CommandTower::Services::Impersonation::TerminateOpenSessions do
  describe ".call" do
    subject(:result) { described_class.call(actor_user_id: actor.id, reason: "revoked") }

    let(:actor) { create(:user) }
    let(:other) { create(:user) }
    let!(:open_session) { create(:impersonation_session, actor:, target: create(:user)) }
    let!(:other_session) { create(:impersonation_session, actor: other, target: create(:user)) }

    before do
      CommandTower::Current.user_id = actor.id
      CommandTower::Current.effective_user_id = actor.id
    end

    after { CommandTower::Current.reset }

    it "ends only the actor's open sessions" do
      expect(result).to be_success
      expect(result.data[:ended_count]).to eq(1)
      expect(open_session.reload.end_reason).to eq("revoked")
      expect(other_session.reload.open?).to be(true)
    end

    it "emits impersonation_ended once" do
      expect { result }.to change { CommandTower::Audit::Event.where(action: "impersonation_ended").count }.by(1)
    end
  end
end

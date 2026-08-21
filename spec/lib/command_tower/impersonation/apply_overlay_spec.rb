# frozen_string_literal: true

RSpec.describe CommandTower::Impersonation::ApplyOverlay do
  describe ".call" do
    subject(:overlay) { described_class.call(actor:, session_id: session.id, mode:) }

    let(:actor) { create(:user) }
    let(:target) { create(:user) }
    let!(:session) { create(:impersonation_session, actor:, target:) }
    let(:mode) { :enforce }

    after { CommandTower::Current.reset }

    it "returns an active overlay" do
      expect(overlay.status).to eq(:active)
      expect(overlay.target).to eq(target)
      expect(overlay.actor).to eq(actor)
    end

    context "when idle has expired" do
      let!(:session) do
        create(:impersonation_session, actor:, target:, idle_expires_at: 1.minute.ago, absolute_expires_at: 1.hour.from_now)
      end

      before do
        CommandTower::Current.user_id = actor.id
        CommandTower::Current.effective_user_id = actor.id
      end

      it "ends the session and returns expired" do
        expect(overlay.status).to eq(:expired)
        expect(session.reload.end_reason).to eq("idle_timeout")
      end

      it "emits impersonation_ended once" do
        expect { overlay }.to change { CommandTower::Audit::Event.where(action: "impersonation_ended").count }.by(1)
      end

      context "when capture mode is used" do
        let(:mode) { :capture }

        it "does not end the session" do
          expect(overlay.status).to eq(:stale)
          expect(session.reload.open?).to be(true)
        end
      end
    end
  end
end

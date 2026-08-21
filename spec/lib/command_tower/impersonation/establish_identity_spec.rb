# frozen_string_literal: true

RSpec.describe CommandTower::Impersonation::EstablishIdentity do
  describe ".call" do
    subject(:established) { described_class.call(actor:, impersonation_session_id: session.id) }

    let(:actor) { create(:user) }
    let(:target) { create(:user) }
    let!(:session) { create(:impersonation_session, actor:, target:) }

    after { CommandTower::Current.reset }

    it "sets dual identity on Current" do
      expect(established.active?).to be(true)
      expect(established.user).to eq(target)
      expect(CommandTower::Current.user_id).to eq(target.id)
      expect(CommandTower::Current.effective_user_id).to eq(target.id)
      expect(CommandTower::Current.originating_administrator_id).to eq(actor.id)
      expect(CommandTower::Current.impersonation_active).to be(true)
      expect(CommandTower::Current.impersonation_session_id).to eq(session.id)
    end

    context "when no overlay claim is present" do
      subject(:established) { described_class.call(actor:, impersonation_session_id: nil) }

      it "sets a normal user identity" do
        expect(established.user).to eq(actor)
        expect(CommandTower::Current.user_id).to eq(actor.id)
        expect(CommandTower::Current.impersonation_active).to be(false)
      end
    end
  end
end

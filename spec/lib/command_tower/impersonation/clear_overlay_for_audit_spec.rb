# frozen_string_literal: true

RSpec.describe CommandTower::Impersonation::ClearOverlayForAudit do
  describe ".call" do
    let(:actor_user_id) { 42 }

    before do
      CommandTower::Current.user_id = 7
      CommandTower::Current.effective_user_id = 99
      CommandTower::Current.originating_administrator_id = 7
      CommandTower::Current.impersonation_active = true
    end

    after { CommandTower::Current.reset }

    it "yields with overlay cleared for admin_direct attribution" do
      described_class.call(actor_user_id:) do
        expect(CommandTower::Current.user_id).to eq(actor_user_id)
        expect(CommandTower::Current.effective_user_id).to eq(actor_user_id)
        expect(CommandTower::Current.originating_administrator_id).to be_nil
        expect(CommandTower::Current.impersonation_active).to eq(false)
      end
    end

    it "restores prior Current attributes after the block" do
      described_class.call(actor_user_id:) { :ok }

      expect(CommandTower::Current.user_id).to eq(7)
      expect(CommandTower::Current.effective_user_id).to eq(99)
      expect(CommandTower::Current.originating_administrator_id).to eq(7)
      expect(CommandTower::Current.impersonation_active).to eq(true)
    end
  end
end

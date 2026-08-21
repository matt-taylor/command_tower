# frozen_string_literal: true

RSpec.describe CommandTower::Services::Impersonation::Create do
  describe ".call" do
    subject(:result) { described_class.call(actor:, target:) }

    let(:actor) { create(:user) }
    let(:target) { create(:user) }

    it "creates an open session" do
      expect(result).to be_success
      expect(result.data[:session]).to be_a(CommandTower::Impersonation::Session)
      expect(result.data[:session].actor_user_id).to eq(actor.id)
      expect(result.data[:session].target_user_id).to eq(target.id)
      expect(result.data[:session].open?).to be(true)
    end

    context "when the same actor starts twice" do
      before { described_class.call(actor:, target:) }

      it "allows concurrent sessions" do
        expect(result).to be_success
        expect(CommandTower::Impersonation::Session.where(actor_user_id: actor.id).count).to eq(2)
      end
    end
  end
end

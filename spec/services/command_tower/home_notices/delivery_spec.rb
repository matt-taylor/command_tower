# frozen_string_literal: true

RSpec.describe CommandTower::HomeNotices::Delivery, :messaging_inbox do
  include HomeNoticeDeliverySpecHelpers

  let(:user) { create(:user) }
  let(:communication_id) { item.communication_id }
  let!(:item) { create_inbox_for(user:) }
  let(:shown) { shown?(delivery_class, user:, communication_id:) }

  describe "#show? for a linked delivery" do
    it "is true while the inbox item is unviewed" do
      expect(shown).to be(true)
    end

    context "when the inbox item was viewed" do
      before { item.update!(viewed_at: Time.current) }

      it "is false" do
        expect(shown).to be(false)
      end
    end

    context "when the inbox item is deleted" do
      before { item.update!(deleted_at: Time.current, status: "deleted") }

      it "is false" do
        expect(shown).to be(false)
      end
    end

    context "when the communication is missing" do
      let(:communication_id) { 0 }

      it "is false" do
        expect(shown).to be(false)
      end
    end

    context "when the inbox item is another user's" do
      let!(:item) { create_inbox_for(user: create(:user)) }

      it "is false" do
        expect(shown).to be(false)
      end
    end

    context "when the notice has no communication" do
      let(:communication_id) { nil }

      it "is false" do
        expect(shown).to be(false)
      end
    end
  end

  describe "#show? for an unlinked delivery" do
    it "is true" do
      expect(shown?(delivery_class(linked: false), user:, communication_id: nil)).to be(true)
    end
  end
end

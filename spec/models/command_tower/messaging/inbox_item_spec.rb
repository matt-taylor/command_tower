# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::InboxItem, type: :model do
  subject(:inbox_item) { create(:messaging_inbox_item, communication:) }

  let(:communication) { create(:messaging_communication) }

  describe "associations" do
    it "belongs to a communication" do
      expect(inbox_item.communication).to eq(communication)
    end
  end

  describe "validations" do
    it "allows one inbox item per communication" do
      expect(inbox_item).to be_persisted
    end

    context "when a duplicate inbox item is built" do
      before { inbox_item }

      subject(:duplicate) { build(:messaging_inbox_item, communication:) }

      it "rejects a second inbox item for the same communication" do
        expect(duplicate).not_to be_valid
        expect(duplicate.errors[:communication_id]).to be_present
      end
    end

    context "when uniqueness is enforced at the database" do
      before { inbox_item }

      it "enforces uniqueness at the database" do
        expect do
          described_class.insert!({
            communication_id: communication.id,
            created_at: Time.current,
            updated_at: Time.current,
          })
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe "lifecycle helpers" do
    context "when freshly created" do
      it "derives predicates and labels from timestamps" do
        expect(inbox_item).not_to be_viewed
        expect(inbox_item).not_to be_archived
        expect(inbox_item).not_to be_deleted
        expect(inbox_item).to be_unread
        expect(inbox_item.lifecycle_label).to eq("created")
      end
    end

    context "when viewed" do
      before { inbox_item.update!(viewed_at: Time.current, status: "viewed") }

      it "derives predicates and labels from timestamps" do
        expect(inbox_item).to be_viewed
        expect(inbox_item).not_to be_unread
        expect(inbox_item.lifecycle_label).to eq("viewed")
      end
    end

    context "when archived" do
      before do
        inbox_item.update!(viewed_at: Time.current, status: "viewed")
        inbox_item.update!(archived_at: Time.current, status: "archived")
      end

      it "derives predicates and labels from timestamps" do
        expect(inbox_item).to be_archived
        expect(inbox_item.lifecycle_label).to eq("archived")
      end
    end

    context "when deleted" do
      before do
        inbox_item.update!(viewed_at: Time.current, status: "viewed")
        inbox_item.update!(archived_at: Time.current, status: "archived")
        inbox_item.update!(deleted_at: Time.current, status: "deleted")
      end

      it "derives predicates and labels from timestamps" do
        expect(inbox_item).to be_deleted
        expect(inbox_item.lifecycle_label).to eq("deleted")
      end
    end

    context "with mixed lifecycle records" do
      let!(:created) { create(:messaging_inbox_item) }
      let!(:viewed) { create(:messaging_inbox_item, :viewed) }
      let!(:archived) { create(:messaging_inbox_item, :archived) }
      let!(:deleted) { create(:messaging_inbox_item, :deleted) }

      it "scopes default list and unread by timestamps" do
        expect(described_class.default_list).to contain_exactly(created, viewed)
        expect(described_class.archived_list).to contain_exactly(archived)
        expect(described_class.unread).to contain_exactly(created)
        expect(described_class.default_list).not_to include(archived, deleted)
        expect(described_class.archived_list).not_to include(created, viewed, deleted)
      end
    end
  end

  describe "independence from channel delivery" do
    let!(:delivery) { create(:messaging_channel_delivery, communication:) }

    it "can exist alongside a channel delivery on the same communication" do
      expect(inbox_item.communication_id).to eq(delivery.communication_id)
      expect(communication.reload.inbox_item).to eq(inbox_item)
      expect(communication.channel_deliveries).to contain_exactly(delivery)
    end
  end
end

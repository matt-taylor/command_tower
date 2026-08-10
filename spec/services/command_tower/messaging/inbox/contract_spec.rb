# frozen_string_literal: true

RSpec.describe CommandTower::Messaging::Inbox, :messaging_inbox do
  let(:user) { create(:user) }
  let(:other_user) { create(:user) }

  describe ".list" do
    context "when listing the default inbox scope" do
      let!(:visible) { create_inbox_for(user:) }

      before do
        create_inbox_for(user:, archived_at: Time.current, status: "archived")
        create_inbox_for(user:, deleted_at: Time.current, status: "deleted")
        create_inbox_for(user: other_user)
      end

      subject(:result) { described_class.list(recipient_id: user.id) }

      it "returns recipient-scoped items excluding archived and deleted" do
        expect(result).to be_a(CommandTower::Messaging::Inbox::ListResult)
        expect(result).not_to be_a(ActiveRecord::Base)
        expect(result.items.map(&:id)).to eq([visible.id])
        expect(result.total_count).to eq(1)
        expect(result.items).to all(be_a(CommandTower::Messaging::Inbox::ItemResult))
        expect(result.items.first).not_to be_a(ActiveRecord::Base)
      end
    end

    context "when ordering by created_at" do
      let!(:older) { create_inbox_for(user:) }
      let!(:newer) { create_inbox_for(user:) }

      before do
        older.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
        newer.update_columns(created_at: 1.day.ago, updated_at: 1.day.ago)
      end

      subject(:result) { described_class.list(recipient_id: user.id) }

      it "orders by created_at desc then id desc" do
        expect(result.items.map(&:id)).to eq([newer.id, older.id])
      end
    end

    context "when applying limit and offset" do
      let!(:first) { create_inbox_for(user:) }
      let!(:second) { create_inbox_for(user:) }
      let!(:third) { create_inbox_for(user:) }

      before do
        first.update_columns(created_at: 3.days.ago)
        second.update_columns(created_at: 2.days.ago)
        third.update_columns(created_at: 1.day.ago)
      end

      subject(:result) { described_class.list(recipient_id: user.id, limit: 1, offset: 1) }

      it "applies limit and offset" do
        expect(result.items.map(&:id)).to eq([second.id])
        expect(result.limit).to eq(1)
        expect(result.offset).to eq(1)
        expect(result.total_count).to eq(3)
      end
    end

    context "when pagination is invalid" do
      it "rejects invalid pagination" do
        expect do
          described_class.list(recipient_id: user.id, limit: 0)
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError)

        expect do
          described_class.list(recipient_id: user.id, limit: 101)
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError)

        expect do
          described_class.list(recipient_id: user.id, offset: -1)
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError)
      end
    end

    context "when scope is archived" do
      let!(:visible) { create_inbox_for(user:) }
      let!(:archived) { create_inbox_for(user:, archived_at: Time.current, status: "archived") }

      before do
        create_inbox_for(user:, deleted_at: Time.current, status: "deleted")
        create_inbox_for(user: other_user, archived_at: Time.current, status: "archived")
      end

      let(:archived_list) { described_class.list(recipient_id: user.id, scope: "archived") }
      let(:inbox_list) { described_class.list(recipient_id: user.id, scope: "inbox") }

      it "lists archived items when scope is archived" do
        expect(archived_list.items.map(&:id)).to eq([archived.id])
        expect(archived_list.total_count).to eq(1)
        expect(inbox_list.items.map(&:id)).to eq([visible.id])
      end
    end

    context "when scope is omitted" do
      let!(:visible) { create_inbox_for(user:) }

      before { create_inbox_for(user:, archived_at: Time.current, status: "archived") }

      subject(:result) { described_class.list(recipient_id: user.id) }

      it "treats omitted scope as inbox" do
        expect(result.items.map(&:id)).to eq([visible.id])
      end
    end

    context "when scope is invalid" do
      it "rejects invalid scope" do
        expect do
          described_class.list(recipient_id: user.id, scope: "trash")
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError, /scope/)
      end
    end
  end

  describe ".show" do
    context "when the item is owned and archived" do
      let!(:item) { create_inbox_for(user:, archived_at: Time.current, status: "archived") }

      subject(:result) { described_class.show(recipient_id: user.id, inbox_item_id: item.id) }

      it "returns an owned item including archived" do
        expect(result.id).to eq(item.id)
        expect(result.recipient_id).to eq(user.id)
        expect(result.status).to eq("archived")
        expect(result.title).to eq(item.communication.title)
      end
    end

    context "when the item is deleted, missing, or cross-recipient" do
      let!(:deleted) { create_inbox_for(user:, deleted_at: Time.current, status: "deleted") }
      let!(:other) { create_inbox_for(user: other_user) }

      it "raises NotFound for deleted, missing, and cross-recipient items" do
        expect do
          described_class.show(recipient_id: user.id, inbox_item_id: deleted.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)

        expect do
          described_class.show(recipient_id: user.id, inbox_item_id: other.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)

        expect do
          described_class.show(recipient_id: user.id, inbox_item_id: 0)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)
      end
    end
  end

  describe ".unread_count" do
    context "when counting unread items" do
      before do
        create_inbox_for(user:)
        create_inbox_for(user:, viewed_at: Time.current, status: "viewed")
        create_inbox_for(user:, archived_at: Time.current, status: "archived")
        create_inbox_for(user:, deleted_at: Time.current, status: "deleted")
        create_inbox_for(user: other_user)
      end

      subject(:result) { described_class.unread_count(recipient_id: user.id) }

      it "counts only unviewed, non-archived, non-deleted items for the recipient" do
        expect(result).to be_a(CommandTower::Messaging::Inbox::UnreadCountResult)
        expect(result.count).to eq(1)
        expect(result.recipient_id).to eq(user.id)
      end
    end
  end

  describe ".mark_viewed" do
    context "when marking viewed twice" do
      let!(:item) { create_inbox_for(user:) }
      let(:first) { described_class.mark_viewed(recipient_id: user.id, inbox_item_id: item.id) }
      let(:second) { described_class.mark_viewed(recipient_id: user.id, inbox_item_id: item.id) }

      before { first && second }

      it "sets viewed_at once and updates denormalized status" do
        expect(first.viewed_at).to be_present
        expect(first.status).to eq("viewed")
        expect(second.viewed_at).to eq(first.viewed_at)
        expect(item.reload.viewed_at).to eq(first.viewed_at)
        expect(item.status).to eq("viewed")
      end
    end

    context "when viewing an archived item" do
      let(:archived_at) { 1.hour.ago.change(usec: 0) }
      let!(:item) { create_inbox_for(user:, archived_at:, status: "archived") }

      subject(:result) { described_class.mark_viewed(recipient_id: user.id, inbox_item_id: item.id) }

      it "does not clear archived_at when viewing an archived item" do
        expect(result.viewed_at).to be_present
        expect(result.archived_at).to be_within(1.second).of(archived_at)
        expect(result.status).to eq("archived")
        expect(item.reload.status).to eq("archived")
      end
    end

    context "when the item is deleted or cross-recipient" do
      let!(:deleted) { create_inbox_for(user:, deleted_at: Time.current, status: "deleted") }
      let!(:other) { create_inbox_for(user: other_user) }

      it "raises NotFound for deleted and cross-recipient items" do
        expect do
          described_class.mark_viewed(recipient_id: user.id, inbox_item_id: deleted.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)

        expect do
          described_class.mark_viewed(recipient_id: user.id, inbox_item_id: other.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)
      end
    end
  end

  describe ".archive" do
    context "when archiving twice" do
      let!(:item) { create_inbox_for(user:) }
      let(:first) { described_class.archive(recipient_id: user.id, inbox_item_id: item.id) }
      let(:second) { described_class.archive(recipient_id: user.id, inbox_item_id: item.id) }

      before { first && second }

      it "soft-archives idempotently" do
        expect(first.archived_at).to be_present
        expect(first.status).to eq("archived")
        expect(second.archived_at).to eq(first.archived_at)
        expect(item.reload.status).to eq("archived")
      end
    end

    context "when the item is deleted" do
      let!(:deleted) { create_inbox_for(user:, deleted_at: Time.current, status: "deleted") }

      it "raises NotFound for deleted items" do
        expect do
          described_class.archive(recipient_id: user.id, inbox_item_id: deleted.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)
      end
    end
  end

  describe ".delete" do
    context "when deleting twice" do
      let!(:item) { create_inbox_for(user:) }
      let(:first) { described_class.delete(recipient_id: user.id, inbox_item_id: item.id) }
      let(:second) { described_class.delete(recipient_id: user.id, inbox_item_id: item.id) }

      before { first && second }

      it "soft-deletes idempotently including already-deleted items" do
        expect(first.deleted_at).to be_present
        expect(first.status).to eq("deleted")
        expect(second.deleted_at).to eq(first.deleted_at)
        expect(item.reload.status).to eq("deleted")
      end
    end

    context "when the item belongs to another recipient" do
      let!(:other) { create_inbox_for(user: other_user) }

      it "raises NotFound for cross-recipient items" do
        expect do
          described_class.delete(recipient_id: user.id, inbox_item_id: other.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)
      end
    end
  end

  describe ".mark_unviewed" do
    context "when clearing viewed_at twice" do
      let!(:item) { create_inbox_for(user:, viewed_at: Time.current, status: "viewed") }
      let(:first) { described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: item.id) }
      let(:second) { described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: item.id) }

      before { first && second }

      it "clears viewed_at once and updates denormalized status" do
        expect(first.viewed_at).to be_nil
        expect(first.status).to eq("created")
        expect(second.viewed_at).to be_nil
        expect(item.reload.viewed_at).to be_nil
        expect(item.status).to eq("created")
      end
    end

    context "when the item is archived" do
      let(:archived_at) { 1.hour.ago.change(usec: 0) }
      let!(:item) { create_inbox_for(user:, viewed_at: Time.current, archived_at:, status: "archived") }

      subject(:result) { described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: item.id) }

      it "keeps archived status when the item is archived" do
        expect(result.viewed_at).to be_nil
        expect(result.archived_at).to be_within(1.second).of(archived_at)
        expect(result.status).to eq("archived")
        expect(item.reload.status).to eq("archived")
      end
    end

    context "when the item was never viewed" do
      let!(:item) { create_inbox_for(user:) }

      subject(:result) { described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: item.id) }

      it "is a noop for items that were never viewed" do
        expect(result.viewed_at).to be_nil
        expect(result.status).to eq("created")
      end
    end

    context "when the item is deleted or cross-recipient" do
      let!(:deleted) do
        create_inbox_for(user:, viewed_at: Time.current, deleted_at: Time.current, status: "deleted")
      end
      let!(:other) { create_inbox_for(user: other_user, viewed_at: Time.current, status: "viewed") }

      it "raises NotFound for deleted and cross-recipient items" do
        expect do
          described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: deleted.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)

        expect do
          described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: other.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)
      end
    end
  end

  describe ".restore" do
    context "when restoring twice from archived" do
      let!(:item) { create_inbox_for(user:, archived_at: Time.current, status: "archived") }
      let(:first) { described_class.restore(recipient_id: user.id, inbox_item_id: item.id) }
      let(:second) { described_class.restore(recipient_id: user.id, inbox_item_id: item.id) }

      before { first && second }

      it "clears archived_at and falls back to created when never viewed" do
        expect(first.archived_at).to be_nil
        expect(first.status).to eq("created")
        expect(second.archived_at).to be_nil
        expect(item.reload.archived_at).to be_nil
        expect(item.status).to eq("created")
      end
    end

    context "when the archived item was already viewed" do
      let!(:item) do
        create_inbox_for(user:, viewed_at: Time.current, archived_at: Time.current, status: "archived")
      end

      subject(:result) { described_class.restore(recipient_id: user.id, inbox_item_id: item.id) }

      it "restores to viewed when the item was already viewed" do
        expect(result.archived_at).to be_nil
        expect(result.viewed_at).to be_present
        expect(result.status).to eq("viewed")
        expect(item.reload.status).to eq("viewed")
      end
    end

    context "when the item is not archived" do
      let!(:item) { create_inbox_for(user:) }

      subject(:result) { described_class.restore(recipient_id: user.id, inbox_item_id: item.id) }

      it "is a noop for items that are not archived" do
        expect(result.archived_at).to be_nil
        expect(result.status).to eq("created")
      end
    end

    context "when the item is deleted or cross-recipient" do
      let!(:deleted) do
        create_inbox_for(user:, archived_at: Time.current, deleted_at: Time.current, status: "deleted")
      end
      let!(:other) { create_inbox_for(user: other_user, archived_at: Time.current, status: "archived") }

      it "raises NotFound for deleted and cross-recipient items" do
        expect do
          described_class.restore(recipient_id: user.id, inbox_item_id: deleted.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)

        expect do
          described_class.restore(recipient_id: user.id, inbox_item_id: other.id)
        end.to raise_error(CommandTower::Messaging::Inbox::NotFoundError)
      end
    end
  end

  describe "bulk request validation" do
    context "when id collections are empty or non-array" do
      it "rejects empty and non-array id collections" do
        expect do
          described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: [])
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError, /required/)

        expect do
          described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: nil)
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError, /array/)
      end
    end

    context "when ids contain blanks" do
      let!(:item) { create_inbox_for(user:) }

      it "rejects blank ids" do
        expect do
          described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: [item.id, ""])
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError, /blank/)
      end
    end

    context "when the batch exceeds the bulk maximum" do
      let(:max) { CommandTower::Messaging::Inbox::Mutator::BULK_MAX_IDS }
      let(:ids) { (1..(max + 1)).to_a }

      it "rejects batches larger than the dedicated bulk maximum" do
        expect do
          described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: ids)
        end.to raise_error(CommandTower::Messaging::Inbox::ValidationError, /at most #{max}/)
      end
    end

    context "when ids are unknown or cross-recipient" do
      let!(:owned) { create_inbox_for(user:) }
      let!(:foreign) { create_inbox_for(user: other_user) }

      subject(:invoke) do
        described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: [owned.id, foreign.id, 0])
      end

      it "rejects unknown and cross-recipient ids with the offending ids" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Inbox::InvalidBulkItemsError) { |error|
          expect(error).to be_a(CommandTower::Messaging::Inbox::ValidationError)
          expect(error.invalid_ids).to eq([foreign.id, 0])
        }

        expect(owned.reload.archived_at).to be_nil
      end
    end

    context "when one id in a bulk delete is invalid" do
      let!(:first) { create_inbox_for(user:) }
      let!(:second) { create_inbox_for(user:) }

      subject(:invoke) do
        described_class.bulk_delete(recipient_id: user.id, inbox_item_ids: [first.id, second.id, 0])
      end

      it "does not persist any change when one id is invalid" do
        expect { invoke }.to raise_error(CommandTower::Messaging::Inbox::InvalidBulkItemsError)

        expect(first.reload.deleted_at).to be_nil
        expect(second.reload.deleted_at).to be_nil
      end
    end

    context "when deleted items are included in live-row operations" do
      let!(:deleted) { create_inbox_for(user:, deleted_at: Time.current, status: "deleted") }
      let(:operations) { %i[bulk_mark_viewed bulk_mark_unviewed bulk_archive bulk_restore] }

      it "rejects deleted items for operations that require a live row" do
        operations.each do |operation|
          expect do
            described_class.public_send(operation, recipient_id: user.id, inbox_item_ids: [deleted.id])
          end.to raise_error(CommandTower::Messaging::Inbox::InvalidBulkItemsError) { |error|
            expect(error.invalid_ids).to eq([deleted.id])
          }
        end
      end
    end

    context "when ids are deduped and string ids are accepted" do
      let!(:first) { create_inbox_for(user:) }
      let!(:second) { create_inbox_for(user:) }

      subject(:result) do
        described_class.bulk_mark_viewed(
          recipient_id: user.id,
          inbox_item_ids: [second.id, first.id.to_s, second.id],
        )
      end

      it "dedupes ids preserving first-seen order and accepts string ids" do
        expect(result).to be_a(CommandTower::Messaging::Inbox::BulkResult)
        expect(result.ids).to eq([second.id, first.id])
        expect(result.count).to eq(2)
        expect(result.changed_count).to eq(2)
      end
    end
  end

  describe ".bulk_mark_viewed" do
    context "when viewing a mixed batch" do
      let!(:unviewed) { create_inbox_for(user:) }
      let!(:viewed) { create_inbox_for(user:, viewed_at: Time.current, status: "viewed") }

      subject(:result) do
        described_class.bulk_mark_viewed(recipient_id: user.id, inbox_item_ids: [unviewed.id, viewed.id])
      end

      it "views every item and counts only the ones that changed" do
        expect(result.ids).to eq([unviewed.id, viewed.id])
        expect(result.count).to eq(2)
        expect(result.changed_count).to eq(1)
        expect(unviewed.reload.status).to eq("viewed")
        expect(unviewed.viewed_at).to be_present
      end
    end
  end

  describe ".bulk_mark_unviewed" do
    context "when clearing viewed_at on a mixed batch" do
      let!(:viewed) { create_inbox_for(user:, viewed_at: Time.current, status: "viewed") }
      let!(:unviewed) { create_inbox_for(user:) }

      subject(:result) do
        described_class.bulk_mark_unviewed(recipient_id: user.id, inbox_item_ids: [viewed.id, unviewed.id])
      end

      it "clears viewed_at and counts only the ones that changed" do
        expect(result.changed_count).to eq(1)
        expect(viewed.reload.viewed_at).to be_nil
        expect(viewed.status).to eq("created")
        expect(unviewed.reload.viewed_at).to be_nil
      end
    end
  end

  describe ".bulk_archive" do
    context "when archiving a mixed batch" do
      let!(:item) { create_inbox_for(user:) }
      let!(:archived) { create_inbox_for(user:, archived_at: Time.current, status: "archived") }

      subject(:result) do
        described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: [item.id, archived.id])
      end

      it "archives every item and counts only the ones that changed" do
        expect(result.changed_count).to eq(1)
        expect(item.reload.status).to eq("archived")
        expect(item.archived_at).to be_present
      end
    end
  end

  describe ".bulk_restore" do
    context "when restoring archived items" do
      let!(:never_viewed) { create_inbox_for(user:, archived_at: Time.current, status: "archived") }
      let!(:previously_viewed) do
        create_inbox_for(
          user:,
          viewed_at: Time.current,
          archived_at: Time.current,
          status: "archived",
        )
      end
      let!(:live) { create_inbox_for(user:) }

      subject(:result) do
        described_class.bulk_restore(
          recipient_id: user.id,
          inbox_item_ids: [never_viewed.id, previously_viewed.id, live.id],
        )
      end

      it "restores archived items to their viewed state" do
        expect(result.changed_count).to eq(2)
        expect(never_viewed.reload.status).to eq("created")
        expect(never_viewed.archived_at).to be_nil
        expect(previously_viewed.reload.status).to eq("viewed")
        expect(previously_viewed.archived_at).to be_nil
      end
    end
  end

  describe ".bulk_delete" do
    context "when deleting a mixed batch" do
      let!(:item) { create_inbox_for(user:) }
      let!(:deleted) { create_inbox_for(user:, deleted_at: Time.current, status: "deleted") }

      subject(:result) do
        described_class.bulk_delete(recipient_id: user.id, inbox_item_ids: [item.id, deleted.id])
      end

      it "soft-deletes items and treats already-deleted items as a noop" do
        expect(result.ids).to eq([item.id, deleted.id])
        expect(result.changed_count).to eq(1)
        expect(item.reload.status).to eq("deleted")
        expect(item.deleted_at).to be_present
      end
    end
  end

  describe "independence from channel execution" do
    context "when mutating inbox items" do
      let!(:item) { create_inbox_for(user:) }

      it "does not create channel deliveries, delivery attempts, or jobs" do
        expect do
          described_class.mark_viewed(recipient_id: user.id, inbox_item_id: item.id)
          described_class.archive(recipient_id: user.id, inbox_item_id: item.id)
          described_class.delete(recipient_id: user.id, inbox_item_id: item.id)
        end.not_to change {
          [
            CommandTower::Messaging::ChannelDelivery.count,
            CommandTower::Messaging::DeliveryAttempt.count,
            enqueued_jobs.size,
          ]
        }
      end
    end
  end

  describe "mutation observability" do
    let(:log_entries) { [] }

    before do
      %i[info warn error].each do |level|
        allow(Rails.logger).to receive(level) do |message|
          log_entries << JSON.parse(message)
        rescue JSON::ParserError
          nil
        end
      end
    end

    context "when lifecycle mutations run repeatedly" do
      let!(:item) { create_inbox_for(user:) }

      before do
        described_class.mark_viewed(recipient_id: user.id, inbox_item_id: item.id)
        described_class.mark_viewed(recipient_id: user.id, inbox_item_id: item.id)
        described_class.archive(recipient_id: user.id, inbox_item_id: item.id)
        described_class.archive(recipient_id: user.id, inbox_item_id: item.id)
        described_class.delete(recipient_id: user.id, inbox_item_id: item.id)
        described_class.delete(recipient_id: user.id, inbox_item_id: item.id)
      end

      let(:events) do
        log_entries.filter_map { |payload| payload["event"] if payload["component"] == "command_tower.messaging" }
      end

      it "logs first successful lifecycle mutations only" do
        expect(events).to eq(
          %w[
            messaging.inbox.viewed
            messaging.inbox.archived
            messaging.inbox.deleted
          ],
        )
        expect(log_entries.flat_map(&:keys)).not_to include("title", "body", "metadata")
      end
    end

    context "when unviewing and restoring" do
      let!(:item) do
        create_inbox_for(user:, viewed_at: Time.current, archived_at: Time.current, status: "archived")
      end

      before do
        described_class.mark_unviewed(recipient_id: user.id, inbox_item_id: item.id)
        described_class.restore(recipient_id: user.id, inbox_item_id: item.id)
      end

      let(:events) do
        log_entries.filter_map { |payload| payload["event"] if payload["component"] == "command_tower.messaging" }
      end

      it "logs unviewed and restored lifecycle events" do
        expect(events).to eq(
          %w[
            messaging.inbox.unviewed
            messaging.inbox.restored
          ],
        )
      end
    end

    context "when bulk archiving with noops" do
      let!(:changed) { create_inbox_for(user:) }
      let!(:already_archived) { create_inbox_for(user:, archived_at: Time.current, status: "archived") }

      before do
        described_class.bulk_archive(recipient_id: user.id, inbox_item_ids: [changed.id, already_archived.id])
      end

      let(:entries) { log_entries.select { |payload| payload["component"] == "command_tower.messaging" } }

      it "logs one bulk-flagged event per changed item and none for noops" do
        expect(entries.map { |payload| payload["event"] }).to eq(%w[messaging.inbox.archived])
        expect(entries.first["bulk"]).to be(true)
        expect(entries.first["inbox_item_id"]).to eq(changed.id)
        expect(log_entries.flat_map(&:keys)).not_to include("title", "body", "metadata")
      end
    end
  end
end

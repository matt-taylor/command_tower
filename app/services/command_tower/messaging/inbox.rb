# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      module_function

      def list(recipient_id:, limit: Reader::DEFAULT_LIMIT, offset: 0, scope: Reader::SCOPE_INBOX)
        Reader.list(recipient_id:, limit:, offset:, scope:)
      end

      def show(recipient_id:, inbox_item_id:)
        Reader.show(recipient_id:, inbox_item_id:)
      end

      def unread_count(recipient_id:)
        Reader.unread_count(recipient_id:)
      end

      def mark_viewed(recipient_id:, inbox_item_id:)
        Mutator.mark_viewed(recipient_id:, inbox_item_id:)
      end

      def mark_unviewed(recipient_id:, inbox_item_id:)
        Mutator.mark_unviewed(recipient_id:, inbox_item_id:)
      end

      def archive(recipient_id:, inbox_item_id:)
        Mutator.archive(recipient_id:, inbox_item_id:)
      end

      def restore(recipient_id:, inbox_item_id:)
        Mutator.restore(recipient_id:, inbox_item_id:)
      end

      def delete(recipient_id:, inbox_item_id:)
        Mutator.delete(recipient_id:, inbox_item_id:)
      end

      def bulk_mark_viewed(recipient_id:, inbox_item_ids:)
        Mutator.bulk_mark_viewed(recipient_id:, inbox_item_ids:)
      end

      def bulk_mark_unviewed(recipient_id:, inbox_item_ids:)
        Mutator.bulk_mark_unviewed(recipient_id:, inbox_item_ids:)
      end

      def bulk_archive(recipient_id:, inbox_item_ids:)
        Mutator.bulk_archive(recipient_id:, inbox_item_ids:)
      end

      def bulk_restore(recipient_id:, inbox_item_ids:)
        Mutator.bulk_restore(recipient_id:, inbox_item_ids:)
      end

      def bulk_delete(recipient_id:, inbox_item_ids:)
        Mutator.bulk_delete(recipient_id:, inbox_item_ids:)
      end
    end
  end
end

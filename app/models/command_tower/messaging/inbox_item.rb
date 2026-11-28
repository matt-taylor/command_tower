# frozen_string_literal: true

module CommandTower
  module Messaging
    class InboxItem < CommandTower::ApplicationRecord
      self.table_name = "messaging_inbox_items"

      STATUS_CREATED = "created"
      STATUS_VIEWED = "viewed"
      STATUS_ARCHIVED = "archived"
      STATUS_DELETED = "deleted"

      belongs_to :communication,
                 class_name: "CommandTower::Messaging::Communication",
                 inverse_of: :inbox_item

      validates :communication_id, uniqueness: true

      scope :not_deleted, -> { where(deleted_at: nil) }
      scope :not_archived, -> { where(archived_at: nil) }
      scope :archived, -> { where.not(archived_at: nil) }
      scope :unresolved, -> { where(resolved_at: nil) }
      scope :resolved, -> { where.not(resolved_at: nil) }
      scope :default_list, -> { not_deleted.not_archived.unresolved }
      scope :archived_list, -> { not_deleted.archived.unresolved }
      # Global rule (unread-count, push badge, mark-all-read): not deleted, archived,
      # resolved or viewed.
      scope :counts_as_unread, -> { default_list.where(viewed_at: nil) }
      # Alias kept for existing callers.
      scope :unread, -> { counts_as_unread }
      # Per-entry rule used by the Reader in both Inbox and Archived scopes: archived rows
      # keep reporting their own unread members. Resolved rows never count.
      scope :unread_in_scope, -> { not_deleted.unresolved.where(viewed_at: nil) }

      def viewed?
        viewed_at.present?
      end

      def archived?
        archived_at.present?
      end

      def deleted?
        deleted_at.present?
      end

      # NPB-5. Archived rows still open the inbox. Deleted rows do not.
      # ChannelRenderer and the Expo adapter both use this predicate.
      def live_for_push?
        !deleted?
      end

      def resolved?
        resolved_at.present?
      end

      # Instance form of the `counts_as_unread` scope.
      def counts_as_unread?
        !viewed? && !archived? && !deleted? && !resolved?
      end
      alias unread? counts_as_unread?

      # Instance form of the `unread_in_scope` scope.
      def unread_in_scope?
        !viewed? && !deleted? && !resolved?
      end

      # Denormalized label helper — timestamps remain authoritative for filters.
      def lifecycle_label
        return STATUS_DELETED if deleted?
        return STATUS_ARCHIVED if archived?
        return STATUS_VIEWED if viewed?

        STATUS_CREATED
      end
    end
  end
end

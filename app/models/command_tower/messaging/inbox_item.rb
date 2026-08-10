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
      scope :default_list, -> { not_deleted.not_archived }
      scope :archived_list, -> { not_deleted.archived }
      scope :unread, -> { default_list.where(viewed_at: nil) }

      def viewed?
        viewed_at.present?
      end

      def archived?
        archived_at.present?
      end

      def deleted?
        deleted_at.present?
      end

      def unread?
        !viewed? && !archived? && !deleted?
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

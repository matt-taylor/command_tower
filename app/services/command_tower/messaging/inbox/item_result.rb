# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      ItemResult = Data.define(
        :id,
        :communication_id,
        :recipient_id,
        :title,
        :status,
        :viewed_at,
        :archived_at,
        :deleted_at,
        :created_at,
        :updated_at,
      ) do
        def self.build(
          id:,
          communication_id:,
          recipient_id:,
          title:,
          status:,
          viewed_at:,
          archived_at:,
          deleted_at:,
          created_at:,
          updated_at:
        )
          new(
            id:,
            communication_id:,
            recipient_id:,
            title: title.to_s,
            status: status.to_s,
            viewed_at:,
            archived_at:,
            deleted_at:,
            created_at:,
            updated_at:,
          ).freeze
        end

        def self.from_record(inbox_item)
          communication = inbox_item.communication
          raise InvariantError, "inbox item missing communication" if communication.nil?

          build(
            id: inbox_item.id,
            communication_id: inbox_item.communication_id,
            recipient_id: communication.user_id,
            title: communication.title,
            status: inbox_item.lifecycle_label,
            viewed_at: inbox_item.viewed_at,
            archived_at: inbox_item.archived_at,
            deleted_at: inbox_item.deleted_at,
            created_at: inbox_item.created_at,
            updated_at: inbox_item.updated_at,
          )
        end
      end
    end
  end
end

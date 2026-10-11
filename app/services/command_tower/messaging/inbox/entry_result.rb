# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      EntryResult = Data.define(
        :kind,
        :id,
        :title,
        :preview,
        :activity_at,
        :created_at,
        :message_count,
        :unread_count,
        :read,
        :inbox_item_ids,
      ) do
        def self.build(kind:, id:, title:, preview:, activity_at:, message_count:, unread_count:, inbox_item_ids:)
          kind = kind.to_s
          new(
            kind:,
            id: kind == "conversation" ? id.to_s : Integer(id),
            title: title.to_s,
            preview: preview&.to_s,
            activity_at:,
            created_at: activity_at,
            message_count: Integer(message_count),
            unread_count: Integer(unread_count),
            read: Integer(unread_count).zero?,
            inbox_item_ids: Array(inbox_item_ids).map { |value| Integer(value) }.freeze,
          ).freeze
        end
      end
    end
  end
end

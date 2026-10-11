# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      ConversationResult = Data.define(
        :scope,
        :subject,
        :message_count,
        :unread_count,
        :inbox_item_ids,
        :message_ids,
        :window,
      ) do
        def self.build(scope:, subject:, message_count:, unread_count:, inbox_item_ids:, message_ids: nil, window: nil)
          ids = Array(inbox_item_ids).map { |value| Integer(value) }.freeze
          rendered = message_ids.nil? ? ids : Array(message_ids).map { |value| Integer(value) }.freeze
          new(
            scope: scope.to_s,
            subject: subject.to_s,
            message_count: Integer(message_count),
            unread_count: Integer(unread_count),
            inbox_item_ids: ids,
            message_ids: rendered,
            window: window&.freeze,
          ).freeze
        end
      end
    end
  end
end

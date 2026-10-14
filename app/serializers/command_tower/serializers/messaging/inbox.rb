# frozen_string_literal: true

module CommandTower
  module Serializers
    module Messaging
      module Inbox
        class EntrySerializer
          def self.serialize(entry)
            {
              kind: entry.fetch(:kind),
              id: entry.fetch(:id),
              title: entry.fetch(:title),
              preview: entry[:preview],
              activityAt: entry.fetch(:activity_at)&.iso8601,
              createdAt: entry.fetch(:created_at)&.iso8601,
              messageCount: entry.fetch(:message_count),
              unreadCount: entry.fetch(:unread_count),
              read: entry.fetch(:read),
              inboxItemIds: entry.fetch(:inbox_item_ids),
            }
          end
        end

        class ConversationSerializer
          def self.serialize(conversation)
            payload = {
              scope: conversation.fetch(:scope),
              subject: conversation.fetch(:subject),
              messageCount: conversation.fetch(:message_count),
              unreadCount: conversation.fetch(:unread_count),
              inboxItemIds: conversation.fetch(:inbox_item_ids),
              messages: conversation.fetch(:messages).map { |message| DetailSerializer.serialize(message) },
            }
            window = conversation[:window]
            payload[:window] = serialize_window(window) if window
            payload
          end

          def self.serialize_window(window)
            {
              anchorInboxItemId: window[:anchor_inbox_item_id],
              hasBefore: window[:has_before],
              hasAfter: window[:has_after],
              beforeCursor: window[:before_cursor],
              afterCursor: window[:after_cursor],
            }
          end
        end

        class ItemSerializer
          def self.serialize(item)
            { id: item.fetch(:id), title: item.fetch(:title), status: item.fetch(:status),
              read: item[:viewed_at].present?, viewedAt: item[:viewed_at]&.iso8601,
              createdAt: item[:created_at]&.iso8601, updatedAt: item[:updated_at]&.iso8601 }
          end
        end

        class DetailSerializer
          def self.serialize(item)
            ItemSerializer.serialize(item).merge(
              body: item.fetch(:body), metadata: item[:metadata],
              notificationTypeKey: item.fetch(:notification_type_key),
              content: item.fetch(:content)
            )
          end
        end

        class BulkResultSerializer
          def self.serialize(result)
            { ids: result.fetch(:ids), count: result.fetch(:count), changedCount: result.fetch(:changed_count) }
          end
        end

        class UnreadCountSerializer
          def self.serialize(payload)
            { count: payload.fetch(:count), badgeCount: payload.fetch(:badge_count) }
          end
        end

        class PaginationMetaSerializer
          def self.serialize(pagination)
            { limit: pagination.fetch(:limit), offset: pagination.fetch(:offset),
              totalCount: pagination.fetch(:total_count) }
          end
        end
      end
    end
  end
end

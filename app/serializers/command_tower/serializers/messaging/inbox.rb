# frozen_string_literal: true

module CommandTower
  module Serializers
    module Messaging
      module Inbox
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
              notificationTypeKey: item.fetch(:notification_type_key)
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
            { count: payload.fetch(:count) }
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

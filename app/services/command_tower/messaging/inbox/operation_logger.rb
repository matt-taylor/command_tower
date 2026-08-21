# frozen_string_literal: true

module CommandTower
  module Messaging
    module Inbox
      class OperationLogger
        EVENT_BY_OPERATION = {
          mark_viewed: "messaging.inbox.viewed",
          mark_unviewed: "messaging.inbox.unviewed",
          archive: "messaging.inbox.archived",
          restore: "messaging.inbox.restored",
          delete: "messaging.inbox.deleted",
        }.freeze

        class << self
          def lifecycle_changed(operation:, item:, bulk: false)
            event = EVENT_BY_OPERATION.fetch(operation)
            Contract::Observability::Publisher.info(
              event:,
              messaging_operation: "inbox",
              operation: operation.to_s,
              bulk:,
              correlation_id: Contract::Observability::Correlation.resolve,
              recipient_id: item.recipient_id,
              inbox_item_id: item.id,
              communication_id: item.communication_id,
              status: item.status,
              viewed_at: item.viewed_at&.utc&.iso8601(3),
              archived_at: item.archived_at&.utc&.iso8601(3),
              deleted_at: item.deleted_at&.utc&.iso8601(3),
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Messaging
    module Planner
      class OperationLogger
        class << self
          def readiness_excluded(
            notification_type_key:,
            recipient_id:,
            channel_key:,
            reason_codes:
          )
            Contract::Observability::Publisher.info(
              event: "messaging.planner.readiness_excluded",
              correlation_id: Contract::Observability::Correlation.resolve,
              messaging_operation: "planner",
              notification_type_key: notification_type_key.to_s,
              recipient_id:,
              channel_key: channel_key.to_s,
              reason_codes: Array(reason_codes).map(&:to_s),
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Messaging
    module Handoff
      class OperationLogger
        class << self
          def scheduled(communication:)
            info("messaging.accept.handoff.scheduled", communication:)
          end

          def started(communication:)
            info("messaging.accept.handoff.started", communication:)
          end

          def succeeded(communication:)
            info("messaging.accept.handoff.succeeded", communication:)
          end

          def failed(communication:, error:)
            emit(
              :error,
              "messaging.accept.handoff.failed",
              communication:,
              error_class: error.class.name,
              error_code: "handoff_execution_failed",
            )
          end

          def enqueue_failed(communication_id:, error:)
            emit(
              :error,
              "messaging.accept.handoff.failed",
              communication_id:,
              error_class: error.class.name,
              error_code: "handoff_enqueue_failed",
            )
          end

          def recovered(communication:)
            info("messaging.accept.handoff.recovered", communication:)
          end

          private

          def info(event, communication:)
            emit(:info, event, communication:)
          end

          def emit(level, event, communication: nil, communication_id: nil, **extra)
            payload = {
              event:,
              correlation_id: Contract::Observability::Correlation.resolve,
              messaging_operation: "accept.handoff",
            }.merge(extra)

            if communication
              payload.merge!(
                communication_id: communication.id,
                execution_handoff_status: communication.execution_handoff_status,
                accept_request_fingerprint: communication.accept_request_fingerprint,
                host_event_identity_digest: Accept::RequestNormalizer.digest_host_event_identity(
                  communication.host_event_identity,
                ),
                channel_delivery_count: communication.channel_deliveries.size,
                inbox_selected: communication.inbox_item.present? ? 1 : 0,
              )
            elsif communication_id
              payload[:communication_id] = communication_id
            end

            Contract::Observability::StructuredLogger.public_send(level, payload)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Observability
        class OperationLogger
          class << self
            def around(operation:, request:)
              correlation_id = Correlation.resolve
              started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
              base = {
                correlation_id:,
                messaging_operation: operation,
              }.merge(request_fields(request))

              StructuredLogger.info(
                base.merge(event: "messaging.#{operation}.started"),
              )

              result = yield

              StructuredLogger.info(
                base.merge(
                  event: "messaging.#{operation}.succeeded",
                  duration_ms: elapsed_ms(started_at),
                ).merge(result_fields(result)),
              )

              result
            rescue Contract::ValidationError => e
              log_failure(base, started_at, operation, e, :warn, "validation_failed")
              raise
            rescue Contract::NotFoundError => e
              log_failure(base, started_at, operation, e, :warn, "not_found")
              raise
            rescue Contract::InvariantError => e
              log_failure(base, started_at, operation, e, :error, "invariant_violation")
              raise
            rescue StandardError => e
              log_failure(base, started_at, operation, e, :error, "unexpected")
              raise
            end

            private

            def log_failure(base, started_at, operation, error, level, error_code)
              StructuredLogger.public_send(
                level,
                base.merge(
                  event: "messaging.#{operation}.failed",
                  duration_ms: elapsed_ms(started_at),
                  error_code:,
                  error_class: error.class.name,
                ),
              )
            end

            def elapsed_ms(started_at)
              ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
            end

            def request_fields(request)
              fields = {}
              fields[:recipient_id] = request.recipient_id if request.respond_to?(:recipient_id)
              if request.respond_to?(:notification_type_key)
                fields[:notification_type_key] = request.notification_type_key
              end
              if request.respond_to?(:communication_id)
                fields[:communication_id] = request.communication_id
              end
              fields.compact
            end

            def result_fields(result)
              return {} unless result.respond_to?(:id)

              fields = { communication_id: result.id }
              if result.respond_to?(:recipient_id)
                fields[:recipient_id] = result.recipient_id
              end
              if result.respond_to?(:notification_type_key)
                fields[:notification_type_key] = result.notification_type_key
              end
              if result.respond_to?(:destination_plan) && result.destination_plan
                fields[:destination_plan_id] = result.destination_plan.id
              end
              if result.respond_to?(:inbox_item) && result.inbox_item
                fields[:inbox_item_id] = result.inbox_item.id
              end
              if result.respond_to?(:channel_deliveries)
                fields[:channel_delivery_count] = result.channel_deliveries.size
              end
              fields.compact
            end
          end
        end
      end
    end
  end
end

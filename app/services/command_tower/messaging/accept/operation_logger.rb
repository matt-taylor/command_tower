# frozen_string_literal: true

module CommandTower
  module Messaging
    module Accept
      class OperationLogger
        class << self
          def around(request:)
            correlation_id = Contract::Observability::Correlation.resolve
            started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            base = {
              correlation_id:,
              messaging_operation: "accept",
              recipient_id: request[:recipient_id],
              notification_type_key: request[:notification_type_key],
              host_event_identity_digest: RequestNormalizer.digest_host_event_identity(
                request[:host_event_identity],
              ),
            }

            Contract::Observability::StructuredLogger.info(
              base.merge(event: "messaging.accept.started"),
            )

            result = yield

            event =
              if result.idempotent_replay
                "messaging.accept.idempotent_replay"
              else
                "messaging.accept.succeeded"
              end

            Contract::Observability::StructuredLogger.info(
              base.merge(
                event:,
                duration_ms: elapsed_ms(started_at),
                communication_id: result.communication_id,
                destination_plan_id: result.destination_plan_id,
                idempotent_replay: result.idempotent_replay,
                selected_channel_count: result.selected_channels.size,
                inbox_selected: result.inbox_selected ? 1 : 0,
              ),
            )

            result
          rescue IdempotencyConflictError => e
            log_failure(base, started_at, e, :warn, "idempotency_conflict", "messaging.accept.idempotency_conflict")
            raise
          rescue ValidationError, UnknownTypeError, InvalidPreferenceError, IllegalOverrideError,
                 ImpossibleMandatoryPlanError => e
            log_failure(base, started_at, e, :warn, error_code_for(e), "messaging.accept.failed")
            raise
          rescue PersistenceError, InvariantError => e
            log_failure(base, started_at, e, :error, error_code_for(e), "messaging.accept.failed")
            raise
          rescue StandardError => e
            log_failure(base, started_at, e, :error, "unexpected", "messaging.accept.failed")
            raise
          end

          private

          def log_failure(base, started_at, error, level, error_code, event)
            Contract::Observability::StructuredLogger.public_send(
              level,
              base.merge(
                event:,
                duration_ms: elapsed_ms(started_at),
                error_code:,
                error_class: error.class.name,
              ),
            )
          end

          def elapsed_ms(started_at)
            ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
          end

          def error_code_for(error)
            case error
            when ValidationError then "validation_failed"
            when UnknownTypeError then "unknown_type"
            when InvalidPreferenceError then "invalid_preference"
            when IllegalOverrideError then "illegal_override"
            when ImpossibleMandatoryPlanError then "impossible_mandatory_plan"
            when IdempotencyConflictError then "idempotency_conflict"
            when PersistenceError then "persistence_failed"
            when InvariantError then "invariant_violation"
            else "unexpected"
            end
          end
        end
      end
    end
  end
end

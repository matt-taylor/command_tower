# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      class OperationLogger
        class << self
          def scheduled(channel_delivery:)
            info("messaging.execution.scheduled", channel_delivery:)
          end

          def claimed(channel_delivery:)
            info("messaging.execution.claimed", channel_delivery:)
          end

          def started(channel_delivery:)
            info("messaging.execution.started", channel_delivery:)
          end

          def succeeded(channel_delivery:)
            info("messaging.execution.succeeded", channel_delivery:)
          end

          def failed(channel_delivery:, error: nil, error_code: "failed_retryable", error_class: nil)
            emit(
              :error,
              "messaging.execution.failed",
              channel_delivery:,
              error_class: error_class || error&.class&.name,
              error_code:,
            )
          end

          def enqueue_failed(channel_delivery_id:, error:)
            emit(
              :error,
              "messaging.execution.failed",
              channel_delivery_id:,
              error_class: error.class.name,
              error_code: "execution_enqueue_failed",
            )
          end

          def recovered(channel_delivery:)
            info("messaging.execution.recovered", channel_delivery:)
          end

          # One aggregate event per recovery sweep. Counts only; nothing when nothing happened.
          def receipts_collected(counts)
            counts = counts.to_h.slice(*ExpoReceiptCollection::COUNT_KEYS)
            return if counts.values.sum.zero?

            failed = counts[:poll_failure_count].to_i.positive? || counts[:update_failure_count].to_i.positive?
            emit(failed ? :error : :info, "messaging.execution.receipts.collected", **counts)
          end

          def attempt_started(channel_delivery:, delivery_attempt:)
            emit_attempt("messaging.execution.attempt.started", channel_delivery:, delivery_attempt:)
          end

          def attempt_succeeded(channel_delivery:, delivery_attempt:)
            emit_attempt("messaging.execution.attempt.succeeded", channel_delivery:, delivery_attempt:)
          end

          def attempt_failed(channel_delivery:, delivery_attempt:)
            emit_attempt(
              "messaging.execution.attempt.failed",
              channel_delivery:,
              delivery_attempt:,
              level: :error,
            )
          end

          def push_destination_fallback(communication:, reason_code:, level:, channel_delivery: nil)
            emit(
              level,
              "messaging.execution.push_destination.fallback",
              channel_delivery:,
              communication_id: communication.id,
              notification_type_key: communication.notification_type_key.to_s,
              reason_code:,
            )
          end

          def push_presentation_fallback(communication:, reason_code:, channel_delivery: nil)
            emit(
              :warn,
              "messaging.execution.push_presentation.fallback",
              channel_delivery:,
              communication_id: communication.id,
              notification_type_key: communication.notification_type_key.to_s,
              reason_code:,
            )
          end

          def attempt_create_failed(channel_delivery:, error:)
            emit(
              :error,
              "messaging.execution.attempt_create_failed",
              channel_delivery:,
              error_class: error.class.name,
              error_code: "attempt_create_failed",
            )
          end

          def attempt_finalize_unpersisted(channel_delivery:, delivery_attempt:, error_class:)
            emit(
              :error,
              "messaging.execution.attempt.finalize_unpersisted",
              channel_delivery:,
              delivery_attempt_id: delivery_attempt.id,
              error_class:,
            )
          end

          def render_started(channel_delivery:, delivery_attempt:)
            emit_render(
              :info,
              "messaging.execution.render.started",
              channel_delivery:,
              delivery_attempt:,
            )
          end

          def render_succeeded(channel_delivery:, delivery_attempt:)
            emit_render(
              :info,
              "messaging.execution.render.succeeded",
              channel_delivery:,
              delivery_attempt:,
            )
          end

          def render_failed(channel_delivery:, delivery_attempt:, error_code:, error_class: nil)
            emit_render(
              :error,
              "messaging.execution.render.failed",
              channel_delivery:,
              delivery_attempt:,
              error_code:,
              error_class:,
            )
          end

          def adapter_started(channel_delivery:, delivery_attempt:)
            emit_adapter(
              :info,
              "messaging.execution.adapter.started",
              channel_delivery:,
              delivery_attempt:,
            )
          end

          def adapter_accepted(channel_delivery:, delivery_attempt:, provider_metadata: nil)
            emit_adapter(
              :info,
              "messaging.execution.adapter.accepted",
              channel_delivery:,
              delivery_attempt:,
              **provider_metadata_counts(provider_metadata),
            )
          end

          def adapter_retryable(channel_delivery:, delivery_attempt:, error_code:, provider_metadata: nil)
            emit_adapter(
              :error,
              "messaging.execution.adapter.retryable",
              channel_delivery:,
              delivery_attempt:,
              error_code:,
              **provider_metadata_counts(provider_metadata),
            )
          end

          def adapter_terminal(channel_delivery:, delivery_attempt:, error_code:, provider_metadata: nil)
            emit_adapter(
              :error,
              "messaging.execution.adapter.terminal",
              channel_delivery:,
              delivery_attempt:,
              error_code:,
              **provider_metadata_counts(provider_metadata),
            )
          end

          def readiness_revalidated(channel_delivery:, delivery_attempt:, ready:)
            emit(
              :info,
              "messaging.execution.readiness.revalidated",
              channel_delivery:,
              delivery_attempt_id: delivery_attempt.id,
              ready: ready ? 1 : 0,
            )
          end

          def readiness_failed(
            channel_delivery:,
            delivery_attempt:,
            error_code:,
            reason_codes: []
          )
            emit(
              :error,
              "messaging.execution.readiness.failed",
              channel_delivery:,
              delivery_attempt_id: delivery_attempt.id,
              error_code:,
              reason_codes: Array(reason_codes).map(&:to_s),
            )
          end

          private

          def emit_render(level, event, channel_delivery:, delivery_attempt:, error_code: nil, error_class: nil)
            emit(
              level,
              event,
              channel_delivery:,
              delivery_attempt_id: delivery_attempt.id,
              error_code:,
              error_class:,
            )
          end

          # extra: optional error_code and provider_metadata counts.
          def emit_adapter(level, event, channel_delivery:, delivery_attempt:, **extra)
            emit(
              level,
              event,
              channel_delivery:,
              delivery_attempt_id: delivery_attempt.id,
              error_code: nil,
              **extra,
            )
          end

          # Counts only; the per-device record stays on the attempt row.
          def provider_metadata_counts(provider_metadata)
            endpoints = provider_metadata.is_a?(Hash) ? provider_metadata.dig("expo", "endpoints") : nil
            return {} unless endpoints.is_a?(Array)

            ticket_statuses = endpoints.pluck("ticket_status")
            {
              endpoint_count: endpoints.size,
              ticket_ok_count: ticket_statuses.count("ok"),
              ticket_error_count: ticket_statuses.count { |status| %w[error missing].include?(status) },
              receipt_pending_count: endpoints.count { |endpoint| endpoint["receipt_status"] == "pending" },
            }
          end

          def info(event, channel_delivery:)
            emit(:info, event, channel_delivery:)
          end

          def emit_attempt(event, channel_delivery:, delivery_attempt:, level: :info)
            emit(
              level,
              event,
              channel_delivery:,
              delivery_attempt_id: delivery_attempt.id,
              attempt_status: delivery_attempt.status,
              error_code: delivery_attempt.error_code,
              error_class: delivery_attempt.error_class,
              provider_message_id: delivery_attempt.provider_message_id,
            )
          end

          def emit(level, event, channel_delivery: nil, channel_delivery_id: nil, **extra)
            payload = {
              event:,
              correlation_id: Contract::Observability::Correlation.resolve,
              messaging_operation: "execution",
            }.merge(extra)

            if channel_delivery
              communication = channel_delivery.communication
              payload.merge!(
                channel_delivery_id: channel_delivery.id,
                communication_id: channel_delivery.communication_id,
                channel_key: channel_delivery.channel_key,
                execution_status: channel_delivery.status,
                execution_attempt_count: channel_delivery.execution_attempt_count,
                host_event_identity_digest: Accept::RequestNormalizer.digest_host_event_identity(
                  communication&.host_event_identity,
                ),
              )
            elsif channel_delivery_id
              payload[:channel_delivery_id] = channel_delivery_id
            end

            Contract::Observability::Publisher.public_send(level, payload)
          end
        end
      end
    end
  end
end

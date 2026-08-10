# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      # DeliveryAttempt + ChannelDelivery ledger writes for start and finalize paths.
      class AttemptLedger
        def self.start(delivery:)
          new.start(delivery:)
        end

        def self.finalize_from_adapter(delivery:, attempt:, result:)
          new.finalize_from_adapter(delivery:, attempt:, result:)
        end

        def self.finalize_terminal(delivery:, attempt:, error_code:)
          new.finalize_terminal(delivery:, attempt:, error_code:)
        end

        def self.finalize_unexpected(delivery:, attempt:, error: nil, error_class: nil)
          new.finalize_unexpected(delivery:, attempt:, error:, error_class:)
        end

        def start(delivery:)
          now = Time.current
          attempt = Messaging::DeliveryAttempt.create!(
            channel_delivery: delivery,
            status: Messaging::DeliveryAttempt::STATUS_STARTED,
            started_at: now,
          )
          OperationLogger.attempt_started(channel_delivery: delivery, delivery_attempt: attempt)
          attempt
        rescue StandardError => error
          mark_failed_retryable_best_effort!(delivery)
          failed = load_delivery(delivery.id)
          OperationLogger.attempt_create_failed(channel_delivery: failed, error:) if failed
          nil
        end

        def finalize_terminal(delivery:, attempt:, error_code:)
          finalize_from_adapter(
            delivery:,
            attempt:,
            result: AdapterResult.build(outcome: :terminal_failure, error_code:),
          )
        end

        def finalize_from_adapter(delivery:, attempt:, result:)
          now = Time.current
          ActiveRecord::Base.transaction do
            case result.outcome
            when :success
              attempt.update!(
                status: Messaging::DeliveryAttempt::STATUS_SUCCEEDED,
                finished_at: now,
                normalized_provider_status: result.normalized_provider_status,
                provider_message_id: result.provider_message_id,
                error_code: nil,
                error_class: nil,
              )
              delivery.update!(status: Messaging::ChannelDelivery::STATUS_ACCEPTED_BY_PROVIDER)
            when :retryable_failure
              attempt.update!(
                status: Messaging::DeliveryAttempt::STATUS_FAILED_RETRYABLE,
                finished_at: now,
                normalized_provider_status: result.normalized_provider_status,
                provider_message_id: result.provider_message_id,
                error_code: result.error_code,
                error_class: nil,
              )
              delivery.update!(status: Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE)
            when :terminal_failure
              attempt.update!(
                status: Messaging::DeliveryAttempt::STATUS_FAILED_TERMINAL,
                finished_at: now,
                normalized_provider_status: result.normalized_provider_status,
                provider_message_id: result.provider_message_id,
                error_code: result.error_code,
                error_class: nil,
              )
              delivery.update!(status: Messaging::ChannelDelivery::STATUS_FAILED_TERMINAL)
            else
              raise InvalidAdapterContractError, "unsupported outcome: #{result.outcome.inspect}"
            end
          end

          delivery.reload
          attempt.reload
          if result.success?
            OperationLogger.attempt_succeeded(channel_delivery: delivery, delivery_attempt: attempt)
            OperationLogger.succeeded(channel_delivery: delivery)
          else
            OperationLogger.attempt_failed(channel_delivery: delivery, delivery_attempt: attempt)
            OperationLogger.failed(
              channel_delivery: delivery,
              error_code: result.error_code || result.outcome.to_s,
              error_class: nil,
            )
          end

          delivery
        end

        def finalize_unexpected(delivery:, attempt:, error: nil, error_class: nil)
          now = Time.current
          resolved_class = error_class || error&.class&.name || "UnknownError"

          ActiveRecord::Base.transaction do
            attempt.update!(
              status: Messaging::DeliveryAttempt::STATUS_FAILED_RETRYABLE,
              finished_at: now,
              error_code: "internal_adapter_error",
              error_class: resolved_class,
              normalized_provider_status: nil,
              provider_message_id: nil,
            )
            delivery.update!(status: Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE)
          end

          delivery.reload
          attempt.reload
          OperationLogger.attempt_failed(channel_delivery: delivery, delivery_attempt: attempt)
          OperationLogger.failed(
            channel_delivery: delivery,
            error_code: "internal_adapter_error",
            error_class: resolved_class,
          )
        rescue StandardError
          mark_failed_retryable_best_effort!(delivery)
        end

        private

        def load_delivery(id)
          Messaging::ChannelDelivery.find_by(id:)
        end

        def mark_failed_retryable_best_effort!(delivery)
          delivery.update(status: Messaging::ChannelDelivery::STATUS_FAILED_RETRYABLE)
        rescue StandardError
          nil
        end
      end
    end
  end
end

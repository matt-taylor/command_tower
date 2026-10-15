# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      class Recovery
        def self.call(
          grace_window: Messaging::DeliveryRetryPolicy::GRACE_WINDOW,
          max_attempts: Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS
        )
          new(grace_window:, max_attempts:).call
        end

        def initialize(
          grace_window: Messaging::DeliveryRetryPolicy::GRACE_WINDOW,
          max_attempts: Messaging::DeliveryRetryPolicy::MAX_ATTEMPTS
        )
          @grace_window = grace_window
          @max_attempts = max_attempts
        end

        def call
          recover_queued!
          recover_failed!
          recover_stale_executing!
          collect_expo_receipts!
        end

        private

        # Runs last so it can never block a redrive. It only reads receipts and updates metadata.
        def collect_expo_receipts!
          ExpoReceiptCollection.call
        rescue StandardError
          OperationLogger.receipts_collected(update_failure_count: 1)
        end

        def grace_before
          @grace_window.ago
        end

        def recover_queued!
          Messaging::ChannelDelivery
            .queued_for_execution
            .where(Messaging::ChannelDelivery.arel_table[:updated_at].lt(grace_before))
            .find_each { |delivery| redrive_queued_delivery!(delivery) }
        end

        def recover_failed!
          Messaging::ChannelDelivery
            .failed_retryable
            .where(Messaging::ChannelDelivery.arel_table[:updated_at].lt(grace_before))
            .find_each { |delivery| redrive_failed_delivery!(delivery) }
        end

        def recover_stale_executing!
          Messaging::ChannelDelivery
            .executing
            .where(Messaging::ChannelDelivery.arel_table[:execution_claimed_at].lt(grace_before))
            .find_each { |delivery| redrive_stale_executing_delivery!(delivery) }
        end

        def redrive_queued_delivery!(delivery)
          if Messaging::DeliveryRetryPolicy.push_channel?(delivery)
            if Messaging::DeliveryRetryPolicy.push_redrive_eligible_while_queued?(delivery)
              redrive!(delivery)
            else
              terminalize_push_uncertain!(delivery)
            end
            return
          end

          redrive!(delivery)
        end

        def redrive_failed_delivery!(delivery)
          if Messaging::DeliveryRetryPolicy.push_channel?(delivery)
            if Messaging::DeliveryRetryPolicy.push_redrive_eligible_from_failed_retryable?(delivery)
              reset_to_queued!(delivery)
              redrive!(delivery.reload)
            else
              terminalize_push_uncertain!(delivery)
            end
            return
          end

          return if delivery.execution_attempt_count >= @max_attempts

          reset_to_queued!(delivery)
          redrive!(delivery.reload)
        end

        def redrive_stale_executing_delivery!(delivery)
          max_attempts = Messaging::DeliveryRetryPolicy.max_execution_attempts_for(delivery)
          return if delivery.execution_attempt_count >= max_attempts

          if Messaging::DeliveryRetryPolicy.push_channel?(delivery)
            if Messaging::DeliveryRetryPolicy.push_redrive_eligible_while_queued?(delivery)
              reset_to_queued!(delivery)
              redrive!(delivery.reload)
            else
              terminalize_push_uncertain!(delivery)
            end
            return
          end

          reset_to_queued!(delivery)
          redrive!(delivery.reload)
        end

        def terminalize_push_uncertain!(delivery)
          now = Time.current
          uncertain = Messaging::DeliveryRetryPolicy::SUBMISSION_UNCERTAIN

          Messaging::DeliveryAttempt
            .where(channel_delivery_id: delivery.id, status: Messaging::DeliveryAttempt::STATUS_STARTED, finished_at: nil)
            .find_each do |attempt|
              attempt.update!(
                status: Messaging::DeliveryAttempt::STATUS_FAILED_TERMINAL,
                finished_at: now,
                error_code: uncertain,
              )
            end

          delivery.update!(status: Messaging::ChannelDelivery::STATUS_FAILED_TERMINAL)
        end

        def reset_to_queued!(delivery)
          delivery.update!(
            status: Messaging::ChannelDelivery::STATUS_QUEUED,
            execution_claimed_at: nil,
          )
        end

        def redrive!(delivery)
          Messaging::ChannelDeliveryExecutionJob.perform_later(delivery.id)
          OperationLogger.recovered(channel_delivery: delivery)
        end
      end
    end
  end
end

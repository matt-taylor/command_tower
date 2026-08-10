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
        end

        private

        def grace_before
          @grace_window.ago
        end

        def recover_queued!
          Messaging::ChannelDelivery
            .queued_for_execution
            .where(Messaging::ChannelDelivery.arel_table[:updated_at].lt(grace_before))
            .find_each { |delivery| redrive!(delivery) }
        end

        def recover_failed!
          Messaging::ChannelDelivery
            .failed_retryable
            .where(Messaging::ChannelDelivery.arel_table[:updated_at].lt(grace_before))
            .where(Messaging::ChannelDelivery.arel_table[:execution_attempt_count].lt(@max_attempts))
            .find_each do |delivery|
              reset_to_queued!(delivery)
              redrive!(delivery.reload)
            end
        end

        def recover_stale_executing!
          Messaging::ChannelDelivery
            .executing
            .where(Messaging::ChannelDelivery.arel_table[:execution_claimed_at].lt(grace_before))
            .find_each do |delivery|
              next if delivery.execution_attempt_count >= @max_attempts

              reset_to_queued!(delivery)
              redrive!(delivery.reload)
            end
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

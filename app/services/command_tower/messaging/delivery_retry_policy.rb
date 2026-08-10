# frozen_string_literal: true

module CommandTower
  module Messaging
    # Authoritative Messaging retry business rules.
    # Consumed by Execution::Recovery (implementation) and Contract mappers (visibility).
    class DeliveryRetryPolicy
      MAX_ATTEMPTS = 5
      GRACE_WINDOW = 1.minute

      class << self
        def retries_exhausted?(delivery)
          delivery.status == ChannelDelivery::STATUS_FAILED_RETRYABLE &&
            delivery.execution_attempt_count >= MAX_ATTEMPTS
        end

        def retry_expected?(delivery)
          delivery.status == ChannelDelivery::STATUS_FAILED_RETRYABLE &&
            !retries_exhausted?(delivery)
        end

        def retry_eligible_at(delivery)
          return nil unless retry_expected?(delivery)

          delivery.updated_at + GRACE_WINDOW
        end
      end
    end
  end
end

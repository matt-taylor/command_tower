# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      # Optimistic CAS: queued → executing. Returns true only when this worker wins.
      class Claim
        def self.call(delivery:)
          new(delivery:).call
        end

        def initialize(delivery:)
          @delivery = delivery
        end

        def call
          now = Time.current
          updated = Messaging::ChannelDelivery.where(
            id: @delivery.id,
            status: Messaging::ChannelDelivery::STATUS_QUEUED,
          ).update_all(
            [
              "status = ?, execution_claimed_at = ?, execution_attempt_count = execution_attempt_count + 1, updated_at = ?",
              Messaging::ChannelDelivery::STATUS_EXECUTING,
              now,
              now,
            ],
          )

          updated == 1
        end
      end
    end
  end
end

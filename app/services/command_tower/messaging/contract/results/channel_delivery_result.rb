# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Results
        ChannelDeliveryResult = Data.define(
          :id,
          :channel_key,
          :status,
          :execution_attempt_count,
          :execution_claimed_at,
          :updated_at,
          :terminal,
          :retries_exhausted,
          :retry_expected,
          :retry_eligible_at,
          :latest_outcome_code,
          :latest_attempt_at,
          :delivery_attempts,
        )
      end
    end
  end
end

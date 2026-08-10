# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Results
        DeliveryAttemptResult = Data.define(
          :id,
          :status,
          :started_at,
          :finished_at,
          :error_code,
          :error_class,
          :normalized_provider_status,
          :provider_message_id,
          :attempt_number,
        )
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Mappers
        class DeliveryAttemptMapper
          def self.to_result(attempt, attempt_number:)
            return nil if attempt.nil?

            Results::DeliveryAttemptResult.new(
              id: attempt.id,
              status: attempt.status,
              started_at: attempt.started_at,
              finished_at: attempt.finished_at,
              error_code: attempt.error_code,
              error_class: attempt.error_class,
              normalized_provider_status: attempt.normalized_provider_status,
              provider_message_id: attempt.provider_message_id,
              attempt_number:,
            ).freeze
          end
        end
      end
    end
  end
end

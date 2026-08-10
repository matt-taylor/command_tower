# frozen_string_literal: true

module CommandTower
  module Messaging
    module Contract
      module Mappers
        class ChannelDeliveryMapper
          def self.to_result(delivery)
            return nil if delivery.nil?

            ordered_attempts = delivery.delivery_attempts.sort_by do |attempt|
              [attempt.started_at, attempt.id]
            end
            latest_attempt = ordered_attempts.last

            Results::ChannelDeliveryResult.new(
              id: delivery.id,
              channel_key: delivery.channel_key,
              status: delivery.status,
              execution_attempt_count: delivery.execution_attempt_count,
              execution_claimed_at: delivery.execution_claimed_at,
              updated_at: delivery.updated_at,
              terminal: delivery.execution_terminal?,
              retries_exhausted: Messaging::DeliveryRetryPolicy.retries_exhausted?(delivery),
              retry_expected: Messaging::DeliveryRetryPolicy.retry_expected?(delivery),
              retry_eligible_at: Messaging::DeliveryRetryPolicy.retry_eligible_at(delivery),
              latest_outcome_code: latest_outcome_code(latest_attempt),
              latest_attempt_at: latest_attempt_at(latest_attempt),
              delivery_attempts: ordered_attempts.each_with_index.map do |attempt, index|
                DeliveryAttemptMapper.to_result(attempt, attempt_number: index + 1)
              end.freeze,
            ).freeze
          end

          def self.latest_outcome_code(attempt)
            return nil if attempt.nil?
            return attempt.error_code if attempt.error_code.present?

            attempt.normalized_provider_status
          end
          private_class_method :latest_outcome_code

          def self.latest_attempt_at(attempt)
            return nil if attempt.nil?

            attempt.finished_at || attempt.started_at
          end
          private_class_method :latest_attempt_at
        end
      end
    end
  end
end

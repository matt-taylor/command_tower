# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      # Execution-time RecipientReadiness revalidation (TOCTOU protection).
      class RevalidateReadiness
        def self.call(delivery:, attempt:, communication:)
          new(delivery:, attempt:, communication:).call
        end

        def initialize(delivery:, attempt:, communication:)
          @delivery = delivery
          @attempt = attempt
          @communication = communication
        end

        # Returns ChannelResult on success, or a String error_code on terminal readiness failure.
        def call
          platform_enabled_channels = platform_enabled_channels_for(@communication)

          begin
            result = RecipientReadiness.for_channel(
              recipient_id: @communication.user_id,
              channel_key: @delivery.channel_key,
              platform_enabled_channels:,
            )
          rescue RecipientReadiness::RecipientNotFoundError
            OperationLogger.readiness_failed(
              channel_delivery: @delivery,
              delivery_attempt: @attempt,
              error_code: "recipient_missing",
              reason_codes: [RecipientReadiness::ReasonCodes::IDENTITY_UNAVAILABLE],
            )
            return "recipient_missing"
          rescue RecipientReadiness::UnknownChannelError
            OperationLogger.readiness_failed(
              channel_delivery: @delivery,
              delivery_attempt: @attempt,
              error_code: "adapter_unconfigured",
              reason_codes: [RecipientReadiness::ReasonCodes::PLATFORM_UNCONFIGURED],
            )
            return "adapter_unconfigured"
          end

          OperationLogger.readiness_revalidated(
            channel_delivery: @delivery,
            delivery_attempt: @attempt,
            ready: result.ready,
          )

          return result if result.ready

          error_code = ReadinessTerminalMapping.error_code_for(result.reason_codes)
          OperationLogger.readiness_failed(
            channel_delivery: @delivery,
            delivery_attempt: @attempt,
            error_code:,
            reason_codes: result.reason_codes,
          )
          error_code
        end

        private

        def platform_enabled_channels_for(communication)
          decision = communication.destination_plan&.decision || {}
          Array(decision["platform_enabled_channels"]).map(&:to_s)
        end
      end
    end
  end
end

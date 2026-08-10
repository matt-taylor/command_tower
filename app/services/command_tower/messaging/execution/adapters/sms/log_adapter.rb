# frozen_string_literal: true

module CommandTower
  module Messaging
    module Execution
      module Adapters
        module Sms
          # Dev-only log adapter. Does not mark platform_configured.
          class LogAdapter
            def call(request:)
              raise ArgumentError, "request must be an AdapterRequest" unless request.is_a?(AdapterRequest)

              Rails.logger.info(
                {
                  component: "command_tower.messaging",
                  event: "messaging.sms.log_adapter",
                  channel_delivery_id: request.channel_delivery_id,
                  attempt_id: request.attempt_id,
                  channel_key: request.channel_key,
                }.to_json,
              )

              AdapterResult.build(
                outcome: :success,
                normalized_provider_status: "logged",
                provider_message_id: "log-#{request.attempt_id}",
              )
            end
          end
        end
      end
    end
  end
end

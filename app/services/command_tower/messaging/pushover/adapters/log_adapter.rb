# frozen_string_literal: true

module CommandTower
  module Messaging
    module Pushover
      module Adapters
        # Dev-only log adapter. Emits safe metadata only; never secrets.
        class LogAdapter
          def validate_user!(user_key:, application_token:)
            Rails.logger.info(
              {
                component: "command_tower.messaging",
                event: "messaging.pushover.log_adapter.validate_user",
                user_key_length: user_key.to_s.length,
                application_token_length: application_token.to_s.length,
              }.to_json,
            )
            Result.ok
          end

          def send_test_notification!(user_key:, application_token:, title:, message:)
            Rails.logger.info(
              {
                component: "command_tower.messaging",
                event: "messaging.pushover.log_adapter.send_test_notification",
                user_key_length: user_key.to_s.length,
                application_token_length: application_token.to_s.length,
                title_length: title.to_s.length,
                message_length: message.to_s.length,
              }.to_json,
            )
            Result.ok
          end

          def send_message!(user_key:, application_token:, title:, message:)
            Rails.logger.info(
              {
                component: "command_tower.messaging",
                event: "messaging.pushover.log_adapter.send_message",
                user_key_length: user_key.to_s.length,
                application_token_length: application_token.to_s.length,
                title_length: title.to_s.length,
                message_length: message.to_s.length,
              }.to_json,
            )
            Result.ok(provider_request_id: "log-message")
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Messaging
    module Pushover
      module Adapters
        # Fail-closed default. Never contacts the provider.
        class DisabledAdapter
          def validate_user!(user_key:, application_token:)
            Result.failure(
              error_code: :adapter_disabled,
              error_message: "Pushover verification adapter is disabled",
            )
          end

          def send_test_notification!(user_key:, application_token:, title:, message:)
            Result.failure(
              error_code: :adapter_disabled,
              error_message: "Pushover verification adapter is disabled",
            )
          end

          def send_message!(user_key:, application_token:, title:, message:)
            Result.failure(
              error_code: :adapter_disabled,
              error_message: "Pushover delivery adapter is disabled",
            )
          end
        end
      end
    end
  end
end

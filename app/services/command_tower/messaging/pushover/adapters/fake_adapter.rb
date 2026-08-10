# frozen_string_literal: true

module CommandTower
  module Messaging
    module Pushover
      module Adapters
        # In-memory / no-network adapter for tests and local development.
        # Inject failures via FakeAdapter.fail_with = :invalid_user | :invalid_token |
        # :invalid_credentials | :timeout | :provider_unavailable | :rate_limited
        class FakeAdapter
          class << self
            attr_accessor :validations, :test_notifications, :messages, :fail_with

            def reset!
              self.validations = []
              self.test_notifications = []
              self.messages = []
              self.fail_with = nil
            end
          end

          self.reset!

          def validate_user!(user_key:, application_token:)
            failure = injected_failure
            return failure if failure

            self.class.validations << {
              user_key_present: user_key.to_s.present?,
              application_token_present: application_token.to_s.present?,
            }
            Result.ok
          end

          def send_test_notification!(user_key:, application_token:, title:, message:)
            failure = injected_failure
            return failure if failure

            self.class.test_notifications << {
              user_key_present: user_key.to_s.present?,
              application_token_present: application_token.to_s.present?,
              title: title.to_s,
              message: message.to_s,
            }
            Result.ok
          end

          def send_message!(user_key:, application_token:, title:, message:)
            failure = injected_failure
            return failure if failure

            self.class.messages << {
              user_key_present: user_key.to_s.present?,
              application_token_present: application_token.to_s.present?,
              title: title.to_s,
              message: message.to_s,
            }
            Result.ok(provider_request_id: "fake-request-#{self.class.messages.size}")
          end

          private

          def injected_failure
            case self.class.fail_with
            when :invalid_user
              Result.failure(error_code: :invalid_user, error_message: "Pushover user key is invalid")
            when :invalid_token
              Result.failure(error_code: :invalid_token, error_message: "Pushover application token is invalid")
            when :invalid_credentials
              Result.failure(error_code: :invalid_credentials, error_message: "Pushover credentials were rejected")
            when :timeout
              Result.failure(error_code: :timeout, error_message: "Pushover provider timed out")
            when :provider_unavailable
              Result.failure(error_code: :provider_unavailable, error_message: "Pushover provider unavailable")
            when :rate_limited
              Result.failure(error_code: :rate_limited, error_message: "Pushover provider rate limited the request")
            when NilClass
              nil
            else
              Result.failure(
                error_code: self.class.fail_with.to_sym,
                error_message: "Pushover provider rejected the request",
              )
            end
          end
        end
      end
    end
  end
end

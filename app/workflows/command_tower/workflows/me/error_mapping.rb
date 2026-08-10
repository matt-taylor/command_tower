# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      # HTTP status mapping for Me/Account workflow failures.
      # Includes phone (2.8) and pushover (host until 2.9) account errors.
      module ErrorMapping
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::ForbiddenError
            :forbidden
          when CommandTower::Errors::Auth::EmailVerificationRequiredError
            :precondition_failed
          when CommandTower::Errors::UnauthorizedError
            :unauthorized
          when CommandTower::Errors::Account::PhoneVerificationCodeInvalidError,
               CommandTower::Errors::Account::PhoneVerificationExpiredError,
               CommandTower::Errors::Account::PhoneVerificationStaleError,
               CommandTower::Errors::Account::PhoneMissingError,
               CommandTower::Errors::Account::PhoneAlreadyVerifiedError,
               CommandTower::Errors::Account::PushoverNotConfiguredError,
               CommandTower::Errors::Account::PushoverAlreadyConfiguredError,
               CommandTower::Errors::Account::PushoverVerificationFailedError,
               CommandTower::Errors::ValidationError
            :unprocessable_entity
          when CommandTower::Errors::Account::PhoneVerificationThrottledError
            :too_many_requests
          when CommandTower::Errors::Account::SmsCapabilityUnavailableError,
               CommandTower::Errors::Account::PushoverCapabilityUnavailableError
            :service_unavailable
          when CommandTower::Errors::Account::PhoneVerificationSendFailedError,
               CommandTower::Errors::Account::PushoverProviderUnavailableError
            :bad_gateway
          when CommandTower::Errors::InternalError
            :internal_server_error
          else
            :internal_server_error
          end
        end
      end
    end
  end
end

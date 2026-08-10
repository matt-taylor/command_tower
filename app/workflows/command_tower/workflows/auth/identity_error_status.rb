# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # HTTP status mapping for the identity lifecycle cluster: email verification,
      # password recovery sessions, and password reset. Session authentication
      # statuses live in SessionErrorStatus; signup statuses in SignupErrorStatus.
      module IdentityErrorStatus
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::Auth::PasswordRecoverySessionMissingError,
               CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError,
               CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError,
               CommandTower::Errors::Auth::PasswordResetInvalidTokenError
            :unauthorized
          when CommandTower::Errors::Auth::PasswordRecoverySessionRateLimitError,
               CommandTower::Errors::Auth::PasswordRecoveryIpRateLimitError
            :too_many_requests
          when CommandTower::Errors::Auth::VerificationCodeInvalidError,
               CommandTower::Errors::ValidationError
            :unprocessable_entity
          when CommandTower::Errors::Auth::PasswordResetUnavailableError
            :service_unavailable
          when CommandTower::Errors::Auth::VerificationSendFailedError
            :bad_gateway
          else
            :internal_server_error
          end
        end
      end
    end
  end
end

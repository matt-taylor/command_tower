# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # Shared HTTP status mapping for the signup cluster only. Scoped deliberately
      # narrow: a platform-wide error mapping table would let unrelated products
      # silently inherit signup's status choices.
      module SignupErrorStatus
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::Auth::SignupSessionMissingError,
               CommandTower::Errors::Auth::SignupSessionInvalidError,
               CommandTower::Errors::Auth::SignupSessionExpiredError
            :unauthorized
          when CommandTower::Errors::Auth::SignupSessionRateLimitError,
               CommandTower::Errors::Auth::SignupIpRateLimitError
            :too_many_requests
          when CommandTower::Errors::Auth::EmailAlreadyRegisteredError,
               CommandTower::Errors::ValidationError
            :unprocessable_entity
          else
            :internal_server_error
          end
        end
      end
    end
  end
end

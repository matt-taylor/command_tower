# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      # HTTP status mapping for session authentication and authorization failures
      # only. Scoped deliberately narrow, same rationale as SignupErrorStatus: a
      # platform-wide table would let unrelated products inherit these choices.
      module SessionErrorStatus
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::Auth::EmailVerificationRequiredError
            :precondition_failed
          when CommandTower::Errors::Auth::CsrfMissingError,
               CommandTower::Errors::Auth::CsrfMismatchError,
               CommandTower::Errors::ForbiddenError
            :forbidden
          when CommandTower::Errors::Auth::InvalidCredentialsError,
               CommandTower::Errors::Auth::ImpersonationSessionExpiredError,
               CommandTower::Errors::UnauthorizedError
            :unauthorized
          else
            :internal_server_error
          end
        end
      end
    end
  end
end

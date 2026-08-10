# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module ErrorStatus
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::ForbiddenError
            :forbidden
          when CommandTower::Errors::Auth::EmailVerificationRequiredError
            :precondition_failed
          when CommandTower::Errors::UnauthorizedError
            :unauthorized
          when CommandTower::Errors::ValidationError
            :unprocessable_entity
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

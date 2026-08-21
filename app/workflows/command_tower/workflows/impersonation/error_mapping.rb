# frozen_string_literal: true

module CommandTower
  module Workflows
    module Impersonation
      module ErrorMapping
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::Auth::SelfImpersonationError,
               CommandTower::Errors::Auth::ImpersonationSessionMissingError,
               CommandTower::Errors::ValidationError
            :unprocessable_entity
          when CommandTower::Errors::Auth::NestedImpersonationError,
               CommandTower::Errors::ForbiddenError
            :forbidden
          when CommandTower::Errors::NotFoundError
            :not_found
          else
            :internal_server_error
          end
        end
      end
    end
  end
end

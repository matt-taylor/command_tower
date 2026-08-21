# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        module ErrorMapping
          module_function

          def http_status_for(error)
            case error
            when CommandTower::Errors::ValidationError
              :unprocessable_entity
            when CommandTower::Errors::ForbiddenError
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
end

# frozen_string_literal: true

module CommandTower
  module Workflows
    module Messaging
      module ErrorMapping
        module_function

        def http_status_for(error)
          case error
          when CommandTower::Errors::ValidationError,
               CommandTower::Errors::Messaging::RecipientUnresolvedError,
               CommandTower::Errors::Messaging::AcceptRejectedError
            :unprocessable_entity
          when CommandTower::Errors::Messaging::IdempotencyConflictError
            :conflict
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

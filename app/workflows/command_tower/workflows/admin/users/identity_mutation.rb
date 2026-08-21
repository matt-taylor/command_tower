# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        module IdentityMutation
          module_function

          def resolve_target(id:, principal:, scope_value:)
            CommandTower::SharedSequences::Admin::Users::ResolveScopedUser.call(
              id:,
              principal:,
              scope_value:
            )
          end

          def map_service_failure(result)
            CommandTower::Workflows::WorkflowResult.failure(
              errors: result.errors,
              http_status: CommandTower::Workflows::Admin::Users::ErrorMapping.http_status_for(
                result.errors.first
              )
            )
          end
        end
      end
    end
  end
end

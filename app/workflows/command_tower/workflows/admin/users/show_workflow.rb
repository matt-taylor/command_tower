# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, scope_value: nil)
            scope_result = resolve_scope(user:, scope_value:)
            return scope_result if scope_result.is_a?(CommandTower::Workflows::WorkflowResult)

            shown = CommandTower::Services::Admin::Users::Show.call(
              id:,
              principal: user,
              scope_context: scope_result
            )
            return result_or_failure(shown) unless shown.success?

            payload = CommandTower::Serializers::Admin::Users::UserSerializer.serialize(
              shown.data[:user]
            )
            success(payload:, http_status: :ok)
          end

          private

          def resolve_scope(user:, scope_value:)
            CommandTower::Workflows::Admin::ScopeResolution.resolve(
              tool_id: "users",
              user:,
              scope_value:
            )
          end

          def result_or_failure(result)
            failure(
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

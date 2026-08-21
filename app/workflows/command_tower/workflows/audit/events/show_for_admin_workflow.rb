# frozen_string_literal: true

module CommandTower
  module Workflows
    module Audit
      module Events
        class ShowForAdminWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(id:, user:, scope_value: nil)
            scope_result = resolve_scope(user:, scope_value:)
            return scope_result if scope_result.is_a?(CommandTower::Workflows::WorkflowResult)

            shown = CommandTower::Services::Audit::Events::Show.call(
              viewer_scope: :admin,
              id:,
              principal: user,
              scope_context: scope_result
            )
            return result_or_failure(shown) unless shown.success?

            projected = CommandTower::Services::Audit::Events::Project.call(
              event: shown.data[:event],
              viewer: :admin
            )
            return result_or_failure(projected) unless projected.success?

            payload = CommandTower::Serializers::Audit::Events::EventSerializer.serialize(
              projected.data[:projection]
            )
            success(payload:, http_status: :ok)
          end

          private

          def resolve_scope(user:, scope_value:)
            CommandTower::Workflows::Admin::ScopeResolution.resolve(
              tool_id: "audit",
              user:,
              scope_value:
            )
          end

          def result_or_failure(result)
            failure(
              errors: result.errors,
              http_status: CommandTower::Workflows::Audit::ErrorMapping.http_status_for(result.errors.first)
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Workflows
    module Audit
      module Events
        class ListForAdminWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(
            limit:,
            offset:,
            user:,
            scope_value: nil,
            actions: nil,
            occurred_after: nil,
            occurred_before: nil,
            subject_types: nil,
            affected_user_id: nil,
            actor_user_id: nil,
            originating_administrator_id: nil,
            attribution_mode: nil
          )
            scope_result = resolve_scope(user:, scope_value:)
            return scope_result if scope_result.is_a?(CommandTower::Workflows::WorkflowResult)

            listed = CommandTower::Services::Audit::Events::List.call(
              viewer_scope: :admin,
              limit:,
              offset:,
              actions:,
              occurred_after:,
              occurred_before:,
              subject_types:,
              affected_user_id:,
              actor_user_id:,
              originating_administrator_id:,
              attribution_mode:,
              principal: user,
              scope_context: scope_result
            )
            return result_or_failure(listed) unless listed.success?

            payload = listed.data[:events].filter_map do |event|
              projected = CommandTower::Services::Audit::Events::Project.call(event:, viewer: :admin)
              return result_or_failure(projected) unless projected.success?

              CommandTower::Serializers::Audit::Events::EventSerializer.serialize(projected.data[:projection])
            end
            meta = CommandTower::Serializers::Audit::Events::PaginationMetaSerializer.serialize(listed.data[:pagination])
            success(payload:, meta:, http_status: :ok)
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

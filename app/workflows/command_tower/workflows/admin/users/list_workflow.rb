# frozen_string_literal: true

module CommandTower
  module Workflows
    module Admin
      module Users
        class ListWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(limit:, offset:, search: nil, user:, scope_value: nil)
            scope_result = resolve_scope(user:, scope_value:)
            return scope_result if scope_result.is_a?(CommandTower::Workflows::WorkflowResult)

            listed = CommandTower::Services::Admin::Users::List.call(
              limit:,
              offset:,
              search:,
              principal: user,
              scope_context: scope_result
            )
            return result_or_failure(listed) unless listed.success?

            payload = listed.data[:users].map do |user|
              CommandTower::Serializers::Admin::Users::UserSerializer.serialize(user)
            end
            meta = CommandTower::Serializers::Admin::Users::PaginationMetaSerializer.serialize(
              listed.data[:pagination]
            )
            success(payload:, meta:, http_status: :ok)
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

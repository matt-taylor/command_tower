# frozen_string_literal: true

module CommandTower
  module SharedSequences
    module Admin
      module Users
        class ResolveScopedUser
          Result = Data.define(:user)

          def self.call(id:, principal:, scope_value: nil)
            new.call(id:, principal:, scope_value:)
          end

          def call(id:, principal:, scope_value: nil)
            scope_result = CommandTower::Workflows::Admin::ScopeResolution.resolve(
              tool_id: "users",
              user: principal,
              scope_value:
            )
            return scope_result if scope_result.is_a?(CommandTower::Workflows::WorkflowResult)

            shown = CommandTower::Services::Admin::Users::Show.call(
              id:,
              principal:,
              scope_context: scope_result
            )
            unless shown.success?
              return CommandTower::Workflows::WorkflowResult.failure(
                errors: shown.errors,
                http_status: CommandTower::Workflows::Admin::Users::ErrorMapping.http_status_for(
                  shown.errors.first
                )
              )
            end

            Result.new(user: shown.data[:user])
          end
        end
      end
    end
  end
end

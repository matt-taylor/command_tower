# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module ExperienceStates
        class CompleteWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, experience_key:, scope_type:, scope_identifier:, version:, auth_context: nil)
            result = CommandTower::Services::Account::ExperienceStates::Complete.call(
              user: current_user,
              experience_key:,
              scope_type:,
              scope_identifier:,
              version:,
            )
            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error),
              )
            end

            if result.data[:created]
              audit(
                :experience_state_completed,
                affected_user: current_user,
                changes: {},
                scope_class: :host,
                host_context: {
                  type: scope_type,
                  identifier: scope_identifier,
                },
              )
            end

            success(
              payload: WorkflowSupport.serialize_view(result.data[:experience_state]),
              http_status: :ok,
              response_effects: WorkflowSupport.expire_header_effects(auth_context),
            )
          end
        end
      end
    end
  end
end

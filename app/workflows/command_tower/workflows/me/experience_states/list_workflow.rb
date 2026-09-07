# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module ExperienceStates
        class ListWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, auth_context: nil)
            result = CommandTower::Services::Account::ExperienceStates::List.call(user: current_user)
            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error),
              )
            end

            success(
              payload: WorkflowSupport.serialize_collection(result.data[:experience_states]),
              http_status: :ok,
              response_effects: WorkflowSupport.expire_header_effects(auth_context),
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module Pushover
        class CreateWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, user_key:, application_token:, auth_context: nil)
            unless CommandTower::Services::Me::PushoverProductGate.enabled?
              return failure(**WorkflowSupport.capability_failure)
            end

            result = CommandTower::Services::Account::Pushover::Create.call(
              user: current_user,
              user_key:,
              application_token:
            )
            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error)
              )
            end

            success(
              payload: WorkflowSupport.serialize_view(result.data[:safe_view]),
              http_status: :ok,
              response_effects: WorkflowSupport.expire_header_effects(auth_context)
            )
          end
        end
      end
    end
  end
end

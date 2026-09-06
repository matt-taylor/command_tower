# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module Push
        class CreateWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, address:, auth_context: nil)
            unless CommandTower::Services::Me::PushProductGate.enabled?
              return failure(**WorkflowSupport.capability_failure)
            end

            result = CommandTower::Services::Account::Push::Create.call(
              user: current_user,
              address:,
            )
            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error),
              )
            end

            success(
              payload: WorkflowSupport.serialize_view(result.data[:safe_view]),
              http_status: :ok,
              response_effects: WorkflowSupport.expire_header_effects(auth_context),
            )
          end
        end
      end
    end
  end
end

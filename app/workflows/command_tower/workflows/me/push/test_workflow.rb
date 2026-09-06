# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module Push
        class TestWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, auth_context: nil)
            unless CommandTower::Services::Me::PushProductGate.enabled?
              return failure(**WorkflowSupport.capability_failure)
            end

            result = CommandTower::Services::Account::Push::SendSelfTest.call(user: current_user)
            unless result.success?
              error = result.errors.first
              return failure(
                errors: result.errors,
                http_status: http_status_for(error),
              )
            end

            success(
              payload: {
                communicationId: result.data[:communication_id],
                destinationPlanId: result.data[:destination_plan_id],
                selectedChannels: result.data[:selected_channels],
                status: result.data[:communication_status],
              },
              http_status: :ok,
              response_effects: WorkflowSupport.expire_header_effects(auth_context),
            )
          end

          private

          def http_status_for(error)
            case error
            when CommandTower::Errors::ValidationError,
                 CommandTower::Errors::Messaging::RecipientUnresolvedError,
                 CommandTower::Errors::Messaging::AcceptRejectedError
              :unprocessable_entity
            when CommandTower::Errors::Messaging::IdempotencyConflictError
              :conflict
            else
              CommandTower::Workflows::Me::ErrorMapping.http_status_for(error)
            end
          end
        end
      end
    end
  end
end

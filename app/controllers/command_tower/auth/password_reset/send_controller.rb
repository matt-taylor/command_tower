# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordReset
      class SendController < CommandTower::ApplicationController
        include CommandTower::Auth::PasswordRecoverySessionBoundary
        include CommandTower::Api::DeserializerFailureDetails

        before_action :authenticate_password_recovery_session!

        def create
          deserialized = CommandTower::Deserializers::Auth::PasswordReset::SendDeserializer.call(params)
          return render_send_deserializer_errors(deserialized) unless deserialized.success?

          result = CommandTower::Workflows::Auth::PasswordReset::SendWorkflow.call(
            input: deserialized.input,
            password_recovery_session: current_password_recovery_session
          )
          render_application_result(result)
        end

        private

        def render_send_deserializer_errors(deserialized)
          render_application_result(
            CommandTower::Workflows::WorkflowResult.failure(
              errors: [
                CommandTower::Errors::ValidationError.new(
                  details: deserializer_failure_details(deserialized)
                )
              ],
              http_status: :unprocessable_entity
            )
          )
        end
      end
    end
  end
end

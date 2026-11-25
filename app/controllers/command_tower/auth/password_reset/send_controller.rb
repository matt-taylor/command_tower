# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordReset
      class SendController < CommandTower::ApplicationController
        include CommandTower::Auth::PasswordRecoverySessionBoundary
        include CommandTower::Api::DeserializerFailureDetails

        # The recovery session is optional: a caller that presents credentials
        # is still authenticated (and rejected when they are invalid), but a
        # caller without any is rate limited by IP alone.
        before_action :authenticate_password_recovery_session!, if: -> { request.authorization.present? }

        def create
          deserialized = CommandTower::Deserializers::Auth::PasswordReset::SendDeserializer.call(params)
          return render_send_deserializer_errors(deserialized) unless deserialized.success?

          result = CommandTower::Workflows::Auth::PasswordReset::SendWorkflow.call(
            input: deserialized.input,
            password_recovery_session: current_password_recovery_session,
            client_ip: request.remote_ip
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

# frozen_string_literal: true

module CommandTower
  module Auth
    module PasswordReset
      class ResetController < CommandTower::ApplicationController
        include CommandTower::Api::ApplicationResponseRenderer
        include CommandTower::Api::DeserializerFailureDetails

        def create
          deserialized = CommandTower::Deserializers::Auth::PasswordReset::ResetDeserializer.call(params)
          return render_reset_deserializer_errors(deserialized) unless deserialized.success?

          result = CommandTower::Workflows::Auth::PasswordReset::ResetWorkflow.call(input: deserialized.input)
          render_application_result(result)
        end

        private

        def render_reset_deserializer_errors(deserialized)
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

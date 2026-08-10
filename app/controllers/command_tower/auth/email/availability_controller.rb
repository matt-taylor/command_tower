# frozen_string_literal: true

module CommandTower
  module Auth
    module Email
      class AvailabilityController < CommandTower::ApplicationController
        include CommandTower::Auth::SignupSessionBoundary

        before_action :authenticate_signup_session!

        def show
          deserialized = CommandTower::Deserializers::Auth::EmailAvailabilityDeserializer.call(params)
          return render_email_deserializer_errors unless deserialized.success?

          result = CommandTower::Workflows::Auth::EmailAvailabilityWorkflow.call(
            input: deserialized.input,
            signup_session: current_signup_session
          )
          render_application_result(result)
        end

        private

        def render_email_deserializer_errors
          render_application_result(
            CommandTower::Workflows::WorkflowResult.failure(
              errors: [CommandTower::Errors::ValidationError.new(details: { email: "Email is required" })],
              http_status: :unprocessable_entity
            )
          )
        end
      end
    end
  end
end

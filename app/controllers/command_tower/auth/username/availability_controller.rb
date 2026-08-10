# frozen_string_literal: true

module CommandTower
  module Auth
    module Username
      class AvailabilityController < CommandTower::ApplicationController
        include CommandTower::Auth::SignupSessionBoundary

        before_action :authenticate_signup_session!

        def show
          deserialized = CommandTower::Deserializers::Auth::UsernameAvailabilityDeserializer.call(params)
          return render_username_deserializer_errors unless deserialized.success?

          result = CommandTower::Workflows::Auth::UsernameAvailabilityWorkflow.call(
            input: deserialized.input,
            signup_session: current_signup_session
          )
          render_application_result(result)
        end

        private

        def render_username_deserializer_errors
          render_application_result(
            CommandTower::Workflows::WorkflowResult.failure(
              errors: [CommandTower::Errors::ValidationError.new(details: { username: "Username is required" })],
              http_status: :unprocessable_entity
            )
          )
        end
      end
    end
  end
end

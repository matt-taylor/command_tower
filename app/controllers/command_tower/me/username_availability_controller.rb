# frozen_string_literal: true

module CommandTower
  module Me
    class UsernameAvailabilityController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      # Same as PATCH /me/username: an unverified account picks its username before verifying email.
      before_action -> { authenticate_request!(bypass_email_validation: true) }
      before_action :authorize_request!

      def show
        deserialized = CommandTower::Deserializers::Auth::UsernameAvailabilityDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::UsernameAvailabilityWorkflow.call(
          current_user: current_user,
          username: deserialized.input.username,
          client_ip: CommandTower::Services::Auth::ClientIpResolver.call(request: request)
        )
        render_application_result(result)
      end

      private

      def render_deserializer_errors
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::ValidationError.new(details: { username: "is required" })],
            http_status: :unprocessable_entity
          )
        )
      end
    end
  end
end

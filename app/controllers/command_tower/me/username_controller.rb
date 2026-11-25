# frozen_string_literal: true

module CommandTower
  module Me
    class UsernameController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      # Setting a username is how an unverified account finishes signup, so the email-verification gate
      # (412) is bypassed. Authentication itself is still required.
      before_action -> { authenticate_request!(bypass_email_validation: true) }
      before_action :authorize_request!

      def update
        deserialized = CommandTower::Deserializers::Me::UpdateUsernameDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::UsernameWorkflow.call(
          current_user: current_user,
          username: deserialized.input.username,
          auth_context: current_auth_context
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

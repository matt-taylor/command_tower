# frozen_string_literal: true

module CommandTower
  module Me
    class PushoverController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def show
        result = CommandTower::Workflows::Me::Pushover::ShowWorkflow.call(
          current_user: current_user,
          auth_context: current_auth_context
        )
        render_application_result(result)
      end

      def create
        deserialized = CommandTower::Deserializers::Me::Pushover::CredentialsDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::Pushover::CreateWorkflow.call(
          current_user: current_user,
          user_key: deserialized.input.user_key,
          application_token: deserialized.input.application_token,
          auth_context: current_auth_context
        )
        render_application_result(result)
      end

      def update
        deserialized = CommandTower::Deserializers::Me::Pushover::CredentialsDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::Pushover::ReplaceWorkflow.call(
          current_user: current_user,
          user_key: deserialized.input.user_key,
          application_token: deserialized.input.application_token,
          auth_context: current_auth_context
        )
        render_application_result(result)
      end

      def destroy
        result = CommandTower::Workflows::Me::Pushover::DestroyWorkflow.call(
          current_user: current_user,
          auth_context: current_auth_context
        )
        render_application_result(result)
      end

      private

      def render_deserializer_errors
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::ValidationError.new(details: { base: "Missing required fields" })],
            http_status: :unprocessable_entity
          )
        )
      end
    end
  end
end

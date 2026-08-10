# frozen_string_literal: true

module CommandTower
  module Me
    class PreferencesController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def show
        deserialized = CommandTower::Deserializers::Messaging::Preferences::ShowDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Messaging::Preferences::ShowWorkflow.call(user: current_user)
        )
      end

      def update
        deserialized = CommandTower::Deserializers::Messaging::Preferences::UpdateDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Messaging::Preferences::UpdateWorkflow.call(
            user: current_user,
            notification_type_key: deserialized.input.notification_type_key,
            preference_state: deserialized.input.preference_state,
          )
        )
      end

      private

      def render_deserializer_errors
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::ValidationError.new(details: { base: "Invalid request parameters" })],
            http_status: :unprocessable_entity
          )
        )
      end
    end
  end
end

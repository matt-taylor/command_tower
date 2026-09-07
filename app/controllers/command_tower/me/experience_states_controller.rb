# frozen_string_literal: true

module CommandTower
  module Me
    class ExperienceStatesController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def index
        result = CommandTower::Workflows::Me::ExperienceStates::ListWorkflow.call(
          current_user: current_user,
          auth_context: current_auth_context,
        )
        render_application_result(result)
      end

      def complete
        deserialized = CommandTower::Deserializers::Me::ExperienceStates::CompleteDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::ExperienceStates::CompleteWorkflow.call(
          current_user: current_user,
          experience_key: deserialized.input.experience_key,
          scope_type: deserialized.input.scope_type,
          scope_identifier: deserialized.input.scope_identifier,
          version: deserialized.input.version,
          auth_context: current_auth_context,
        )
        render_application_result(result)
      end

      private

      def render_deserializer_errors
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [
              CommandTower::Errors::ValidationError.new(
                details: { base: "Missing or invalid experience state completion fields" },
              ),
            ],
            http_status: :unprocessable_entity,
          ),
        )
      end
    end
  end
end

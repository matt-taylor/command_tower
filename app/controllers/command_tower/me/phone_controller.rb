# frozen_string_literal: true

module CommandTower
  module Me
    class PhoneController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def update
        deserialized = CommandTower::Deserializers::Me::UpdatePhoneDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::UpdatePhoneWorkflow.call(
          current_user: current_user,
          phone_number: deserialized.input.phone_number,
          auth_context: current_auth_context
        )
        render_application_result(result)
      end

      def destroy
        result = CommandTower::Workflows::Me::ClearPhoneWorkflow.call(
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

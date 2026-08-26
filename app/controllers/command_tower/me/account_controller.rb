# frozen_string_literal: true

module CommandTower
  module Me
    class AccountController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def destroy
        deserialized = CommandTower::Deserializers::Me::DeleteAccountDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::DeleteAccountWorkflow.call(
          current_user: current_user,
          password: deserialized.input.password
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

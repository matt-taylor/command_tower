# frozen_string_literal: true

module CommandTower
  module Me
    class PushController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def index
        result = CommandTower::Workflows::Me::Push::IndexWorkflow.call(
          current_user: current_user,
          auth_context: current_auth_context,
        )
        render_application_result(result)
      end

      def create
        deserialized = CommandTower::Deserializers::Me::Push::TokenDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::Push::CreateWorkflow.call(
          current_user: current_user,
          address: deserialized.input.address,
          auth_context: current_auth_context,
        )
        render_application_result(result)
      end

      def update
        deserialized = CommandTower::Deserializers::Me::Push::TokenDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Me::Push::ReplaceWorkflow.call(
          current_user: current_user,
          endpoint_id: params[:id],
          address: deserialized.input.address,
          auth_context: current_auth_context,
        )
        render_application_result(result)
      end

      def destroy
        result = CommandTower::Workflows::Me::Push::DestroyWorkflow.call(
          current_user: current_user,
          endpoint_id: params[:id],
          auth_context: current_auth_context,
        )
        render_application_result(result)
      end

      private

      def render_deserializer_errors
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::ValidationError.new(details: { base: "Missing or invalid push token" })],
            http_status: :unprocessable_entity,
          ),
        )
      end
    end
  end
end

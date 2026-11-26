# frozen_string_literal: true

module CommandTower
  module Auth
    class PasswordCheckController < CommandTower::ApplicationController
      include CommandTower::Api::ApplicationResponseRenderer

      def create
        deserialized = CommandTower::Deserializers::Auth::PasswordCheckDeserializer.call(params)
        return render_missing_password unless deserialized.success?

        result = CommandTower::Workflows::Auth::PasswordCheckWorkflow.call(
          input: deserialized.input,
          client_ip: CommandTower::Services::Auth::ClientIpResolver.call(request: request)
        )
        render_application_result(result)
      end

      private

      def render_missing_password
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::ValidationError.new(details: { password: "Password is required" })],
            http_status: :unprocessable_entity
          )
        )
      end
    end
  end
end

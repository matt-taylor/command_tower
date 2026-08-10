# frozen_string_literal: true

module CommandTower
  module Auth
    class RegisterController < CommandTower::ApplicationController
      include CommandTower::Api::ApplicationResponseRenderer

      def create
        deserialized = CommandTower::Deserializers::Auth::RegisterDeserializer.call(params)
        return render_register_deserializer_errors unless deserialized.success?

        result = CommandTower::Workflows::Auth::RegisterWorkflow.call(
          input: deserialized.input,
          client_ip: CommandTower::Services::Auth::ClientIpResolver.call(request: request)
        )
        render_application_result(result)
      end

      private

      # Collapses per-field deser failures into one message so registration never
      # discloses which individual fields the caller got wrong.
      def render_register_deserializer_errors
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

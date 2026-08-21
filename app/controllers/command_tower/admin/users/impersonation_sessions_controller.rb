# frozen_string_literal: true

module CommandTower
  module Admin
    module Users
      class ImpersonationSessionsController < CommandTower::Admin::ApplicationController
        def create
          deserialized = CommandTower::Deserializers::Admin::Users::ShowDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Impersonation::StartWorkflow.call(
              id: deserialized.input.id,
              actor: current_user,
              scope_value: deserialized.input.scope_value
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
end

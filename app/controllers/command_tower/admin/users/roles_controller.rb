# frozen_string_literal: true

module CommandTower
  module Admin
    module Users
      class RolesController < CommandTower::Admin::ApplicationController
        def index
          render_application_result(
            CommandTower::Workflows::Admin::Users::ListAssignableRolesWorkflow.call
          )
        end

        def update
          deserialized = CommandTower::Deserializers::Admin::Users::UpdateRolesDeserializer.call(params)
          return render_deserializer_errors unless deserialized.success?

          render_application_result(
            CommandTower::Workflows::Admin::Users::UpdateRolesWorkflow.call(
              id: deserialized.input.id,
              user: current_user,
              roles: deserialized.input.roles,
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

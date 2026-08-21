# frozen_string_literal: true

module CommandTower
  module Admin
    class UsersController < CommandTower::Admin::ApplicationController
      def index
        deserialized = CommandTower::Deserializers::Admin::Users::ListDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Admin::Users::ListWorkflow.call(
            limit: deserialized.input.limit,
            offset: deserialized.input.offset,
            search: deserialized.input.search,
            user: current_user,
            scope_value: deserialized.input.scope_value
          )
        )
      end

      def show
        deserialized = CommandTower::Deserializers::Admin::Users::ShowDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Admin::Users::ShowWorkflow.call(
            id: deserialized.input.id,
            user: current_user,
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

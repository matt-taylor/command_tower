# frozen_string_literal: true

module CommandTower
  module Me
    class AuditEventsController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def index
        deserialized = CommandTower::Deserializers::Audit::Events::UserListDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Audit::Events::ListForUserWorkflow.call(
            user: current_user,
            limit: deserialized.input.limit,
            offset: deserialized.input.offset,
            actions: deserialized.input.actions,
            occurred_after: deserialized.input.occurred_after,
            occurred_before: deserialized.input.occurred_before,
            subject_types: deserialized.input.subject_types
          )
        )
      end

      def show
        deserialized = CommandTower::Deserializers::Audit::Events::ShowDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Audit::Events::ShowForUserWorkflow.call(
            user: current_user,
            id: deserialized.input.id
          )
        )
      end

      def filter_options
        render_application_result(
          CommandTower::Workflows::Audit::Events::FilterOptionsForUserWorkflow.call
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

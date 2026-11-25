# frozen_string_literal: true

module CommandTower
  module Admin
    # The home-notice kill switch. Needs the `admin_home_notices_kill` grant (not in the principal
    # capabilities catalog) and is refused while impersonating, by `Admin::ApplicationController`.
    class HomeNoticesController < CommandTower::Admin::ApplicationController
      before_action :set_no_store

      def update
        deserialized = CommandTower::Deserializers::Admin::HomeNotices::ControlDeserializer.call(params)
        return render_deserializer_errors unless deserialized.success?

        render_application_result(
          CommandTower::Workflows::Admin::HomeNotices::UpdateControlWorkflow.call(
            user: current_user,
            key: deserialized.input.key,
            enabled: deserialized.input.enabled
          )
        )
      end

      private

      def set_no_store
        response.headers["Cache-Control"] = "no-store"
      end

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

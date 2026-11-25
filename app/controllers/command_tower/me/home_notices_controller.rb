# frozen_string_literal: true

module CommandTower
  module Me
    class HomeNoticesController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      before_action :set_no_store

      def index
        result = CommandTower::Workflows::HomeNotices::ShowWorkflow.call(
          user: current_user,
          impersonating: impersonating_flag,
          app_version: header_value("X-App-Version"),
          platform: header_value("X-Client-Platform")&.downcase
        )
        render_application_result(result)
      end

      def impression
        mutate(CommandTower::Workflows::HomeNotices::RecordImpressionWorkflow)
      end

      def acknowledge
        mutate(CommandTower::Workflows::HomeNotices::AcknowledgeWorkflow)
      end

      def dismiss
        mutate(CommandTower::Workflows::HomeNotices::DismissWorkflow)
      end

      private

      def mutate(workflow)
        deserialized = CommandTower::Deserializers::HomeNotices::NoticeIdDeserializer.call(params)
        return render_not_found unless deserialized.success?

        result = workflow.call(
          user: current_user,
          notice_id: deserialized.input,
          impersonating: impersonating_flag,
          app_version: header_value("X-App-Version"),
          platform: header_value("X-Client-Platform")&.downcase
        )
        render_application_result(result)
      end

      # A malformed id names no notice.
      def render_not_found
        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::NotFoundError.new], http_status: :not_found
          )
        )
      end

      # Notices are per user and redacted while impersonating: never cache them.
      def set_no_store
        response.headers["Cache-Control"] = "no-store"
      end

      # From the authentication result: true while impersonating, false for a normal session,
      # nil when there is no auth context (unknown, which redacts).
      def impersonating_flag
        return nil if current_auth_context.nil?

        CommandTower::Current.impersonation_active == true
      end

      def header_value(name)
        request.headers[name].to_s.strip.presence
      end
    end
  end
end

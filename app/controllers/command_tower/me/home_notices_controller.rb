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

      private

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

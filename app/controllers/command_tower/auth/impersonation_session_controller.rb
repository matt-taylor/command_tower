# frozen_string_literal: true

module CommandTower
  module Auth
    class ImpersonationSessionController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Api::ApplicationResponseRenderer

      before_action :authenticate_stop_request!

      def destroy
        result = CommandTower::Workflows::Impersonation::StopWorkflow.call(
          actor: current_auth_context.actor_user,
          impersonation_session_id: current_auth_context.impersonation_session_id,
          token_expires_at: current_auth_context.token_expires_at
        )
        render_application_result(result)
      end

      private

      def authenticate_stop_request!
        authenticate_request!(overlay_mode: :capture)
      end
    end
  end
end

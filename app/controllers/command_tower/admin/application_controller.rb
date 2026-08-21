# frozen_string_literal: true

module CommandTower
  module Admin
    class ApplicationController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!
      before_action :reject_admin_operations_during_impersonation!

      private

      def reject_admin_operations_during_impersonation!
        return unless CommandTower::Current.impersonation_active

        render_application_result(
          CommandTower::Workflows::WorkflowResult.failure(
            errors: [CommandTower::Errors::Auth::AdminUnavailableDuringImpersonationError.new],
            http_status: 418
          )
        )
      end
    end
  end
end

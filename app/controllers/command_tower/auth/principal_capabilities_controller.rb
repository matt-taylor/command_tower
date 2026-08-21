# frozen_string_literal: true

module CommandTower
  module Auth
    class PrincipalCapabilitiesController < CommandTower::ApplicationController
      include CommandTower::Auth::AuthenticationBoundary
      include CommandTower::Auth::AuthorizationBoundary

      before_action :authenticate_request!
      before_action :authorize_request!

      def show
        render_application_result(
          CommandTower::Workflows::Auth::PrincipalCapabilities::ShowWorkflow.call(user: current_user)
        )
      end
    end
  end
end

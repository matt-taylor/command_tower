# frozen_string_literal: true

module CommandTower
  class MeController < CommandTower::ApplicationController
    include CommandTower::Auth::AuthenticationBoundary
    include CommandTower::Auth::AuthorizationBoundary

    before_action :authenticate_request!
    before_action :authorize_request!

    def show
      result = CommandTower::Workflows::Me::ShowWorkflow.call(
        current_user: current_user,
        auth_context: current_auth_context
      )
      render_application_result(result)
    end
  end
end

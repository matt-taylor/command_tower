# frozen_string_literal: true

module CommandTower
  module Auth
    class LogoutController < CommandTower::ApplicationController
      include CommandTower::Api::ApplicationResponseRenderer

      def create
        result = CommandTower::Workflows::Auth::LogoutWorkflow.call
        render_application_result(result)
      end
    end
  end
end

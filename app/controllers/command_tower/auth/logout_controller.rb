# frozen_string_literal: true

module CommandTower
  module Auth
    class LogoutController < CommandTower::ApplicationController
      include CommandTower::Api::ApplicationResponseRenderer

      def create
        token_data = CommandTower::Jwt::AuthorizationHelper.extract_token(request)
        token = token_data[:error] ? nil : token_data[:token]
        result = CommandTower::Workflows::Auth::LogoutWorkflow.call(token:)
        render_application_result(result)
      end
    end
  end
end

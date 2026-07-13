# frozen_string_literal: true

module CommandTower
  module Auth
    class LogoutController < ::CommandTower::ApplicationController
      include CommandTower::SchemaHelper

      # POST /auth/logout
      # Logs out the current browser session by clearing the JWT cookie
      # Does NOT modify verifier_token (browser-only logout)
      def logout_post
        # Clear cookie if cookie auth is enabled
        CommandTower::Jwt::AuthorizationHelper.clear_token(response)

        schema = CommandTower::Schema::Auth::Logout::Response.new(
          message: "Logged out"
        )
        status = 200
        schema_succesful!(status:, schema:)
      end
    end
  end
end

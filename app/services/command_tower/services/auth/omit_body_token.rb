# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      # Decides whether a login response body leaves out `token`. Only the new web client, in cookie
      # mode, reads the session from the cookie. v0.1.22 native stores the body token, and
      # X-Client-Platform is optional, so any other or unknown client keeps the body token.
      # Reads the client identity the HTTP boundary put on CommandTower::Current.
      class OmitBodyToken
        def self.call
          new.omit?
        end

        def omit?
          config = CommandTower.config.session
          return false unless config.omit_body_token
          return false unless CommandTower::Jwt::AuthorizationHelper.cookie_enabled?
          return false unless CommandTower::Current.client_platform == "web"

          app_version = CommandTower::ClientCompatibility::Version.parse(CommandTower::Current.client_app_version)
          minimum = CommandTower::ClientCompatibility::Version.parse(config.omit_body_token_min_app_version)
          return false if app_version.nil? || minimum.nil?

          app_version >= minimum
        end
      end
    end
  end
end

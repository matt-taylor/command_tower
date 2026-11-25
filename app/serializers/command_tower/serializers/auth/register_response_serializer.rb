# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class RegisterResponseSerializer
        # Without `token_expires_at` the body is the legacy `{ user, message }`. A started session
        # adds the login-shaped `token` and `tokenExpiresAt`; include_token: false drops `token`
        # for the cookie-mode web client (same rule as login).
        def self.serialize(user:, token: nil, token_expires_at: nil, include_token: true, capabilities: nil)
          body = {
            user: UserSerializer.serialize(user),
            message: "Account created successfully"
          }
          return body if token_expires_at.nil?

          body[:token] = token if include_token
          body[:tokenExpiresAt] = token_expires_at
          body[:capabilities] = capabilities if capabilities
          body
        end
      end
    end
  end
end

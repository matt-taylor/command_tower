# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class LoginResponseSerializer
        # include_token: false drops `token` from the body (cookie-mode web client); tokenExpiresAt stays.
        def self.serialize(user:, token:, token_expires_at:, include_token: true)
          body = { user: UserSerializer.serialize(user) }
          body[:token] = token if include_token
          body[:tokenExpiresAt] = token_expires_at
          body
        end
      end
    end
  end
end

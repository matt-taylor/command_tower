# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class LoginResponseSerializer
        def self.serialize(user:, token:, token_expires_at:)
          {
            user: UserSerializer.serialize(user),
            token: token,
            tokenExpiresAt: token_expires_at
          }
        end
      end
    end
  end
end

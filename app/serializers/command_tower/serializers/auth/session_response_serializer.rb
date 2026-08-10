# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class SessionResponseSerializer
        def self.serialize(user:, token_expires_at:)
          {
            user: CommandTower::Serializers::Auth::UserSerializer.serialize(user),
            tokenExpiresAt: token_expires_at
          }
        end
      end
    end
  end
end

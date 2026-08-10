# frozen_string_literal: true

module CommandTower
  module Serializers
    module Auth
      class SignupSessionResponseSerializer
        def self.serialize(token:, expires_at:)
          {
            signupSessionToken: token,
            expiresAt: expires_at.iso8601
          }
        end
      end
    end
  end
end

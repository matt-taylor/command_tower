# frozen_string_literal: true

require "jwt"

module CommandTower
  module Services
    module Auth
      module PasswordRecoverySession
        class Encode < CommandTower::Services::ApplicationService
          validate :jti, is_a: String, required: true
          validate :expires_at, is_a: Time, required: true

          def call
            config = CommandTower.config.password_recovery_session

            payload = {
              iss: config.issuer,
              aud: config.audience,
              purpose: config.purpose,
              jti: jti,
              iat: Time.now.to_i,
              exp: expires_at.to_i
            }

            context.token = JWT.encode(payload, config.jwt_secret, "HS256")
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "jwt"

module CommandTower
  module Services
    module Auth
      module PasswordRecoverySession
        class Decode < CommandTower::Services::ApplicationService
          validate :token, is_a: String, required: true, sensitive: true

          def call
            data = JWT.decode(
              token,
              CommandTower.config.password_recovery_session.jwt_secret,
              true,
              { algorithm: "HS256" }
            )
            context.payload = data.first.with_indifferent_access
          rescue JWT::ExpiredSignature
            context.fail!(application_error: CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError.new)
          rescue JWT::DecodeError
            context.fail!(application_error: CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError.new)
          end
        end
      end
    end
  end
end

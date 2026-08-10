# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordRecoverySession
        class Validate < CommandTower::Services::ApplicationService
          validate :token, is_a: String, required: true, sensitive: true
          validate :client_ip, is_a: String, required: true

          def call
            decode_result = Decode.call(token: token)
            unless decode_result.success?
              context.fail!(application_error: decode_result.errors.first)
              return
            end

            payload = decode_result.data[:payload]
            validation_error = validate_claims(payload)
            if validation_error
              context.fail!(application_error: validation_error)
              return
            end

            expires_at = Time.at(payload[:exp].to_i).utc
            if expires_at <= Time.now.utc
              context.fail!(application_error: CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError.new)
              return
            end

            context.password_recovery_session = CommandTower::Auth::PasswordRecoverySessionContext.new(
              jti: payload[:jti].to_s,
              expires_at: expires_at,
              client_ip: client_ip
            )
          end

          private

          def validate_claims(payload)
            config = CommandTower.config.password_recovery_session

            return invalid_error if payload[:jti].blank?
            return invalid_error if payload[:iss] != config.issuer
            return invalid_error if payload[:aud] != config.audience
            return invalid_error if payload[:purpose] != config.purpose

            nil
          end

          def invalid_error
            CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError.new
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordRecoverySession
        class Create < CommandTower::Services::ApplicationService
          def call
            jti = SecureRandom.uuid
            expires_at = CommandTower.config.password_recovery_session.ttl.from_now.utc

            encode_result = Encode.call(jti: jti, expires_at: expires_at)
            unless encode_result.success?
              context.fail!(application_error: CommandTower::Errors::InternalError.new)
              return
            end

            context.token = encode_result.data[:token]
            context.expires_at = expires_at
            context.jti = jti
          end
        end
      end
    end
  end
end

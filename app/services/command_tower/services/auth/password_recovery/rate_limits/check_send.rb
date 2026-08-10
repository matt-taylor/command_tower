# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordRecovery
        module RateLimits
          class CheckSend < CommandTower::Services::ApplicationService
            include Enforcement

            validate :password_recovery_session,
              is_a: CommandTower::Auth::PasswordRecoverySessionContext,
              required: true

            def call
              remaining = password_recovery_session.remaining_seconds
              expired_session! if remaining <= 0

              jti_ttl = remaining + CommandTower.config.password_recovery_session.cleanup_buffer_seconds

              enforce!(
                key: "password-recovery:rate:jti:#{password_recovery_session.jti}:send",
                ttl_seconds: jti_ttl,
                limit: limits.jti_send,
                scope: :session
              )

              enforce!(
                key: "password-recovery:rate:ip:#{normalize_ip(password_recovery_session.client_ip)}:send:1h:#{hour_bucket}",
                ttl_seconds: 3600,
                limit: limits.ip_send_hour,
                scope: :ip
              )
            end

            private

            def expired_session!
              context.fail!(
                application_error: CommandTower::Errors::Auth::PasswordRecoverySessionExpiredError.new
              )
            end
          end
        end
      end
    end
  end
end

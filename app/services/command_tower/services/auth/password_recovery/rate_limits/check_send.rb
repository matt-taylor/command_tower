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
              required: false
            validate :client_ip, is_a: String, required: false

            def call
              enforce_session_budget! if password_recovery_session

              enforce!(
                key: "password-recovery:rate:ip:#{normalize_ip(password_recovery_session&.client_ip || client_ip)}:send:1h:#{hour_bucket}",
                ttl_seconds: 3600,
                limit: limits.ip_send_hour,
                scope: :ip
              )
            end

            private

            def enforce_session_budget!
              remaining = password_recovery_session.remaining_seconds
              expired_session! if remaining <= 0

              enforce!(
                key: "password-recovery:rate:jti:#{password_recovery_session.jti}:send",
                ttl_seconds: remaining + CommandTower.config.password_recovery_session.cleanup_buffer_seconds,
                limit: limits.jti_send,
                scope: :session
              )
            end

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

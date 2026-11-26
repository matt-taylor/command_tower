# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordPolicy
        # Per-IP ceiling for POST /auth/password-check (60 per minute). Fails open: a Redis
        # failure never blocks a live password check.
        class CheckRateLimit < CommandTower::Services::ApplicationService
          LIMIT_PER_MINUTE = 60

          validate :client_ip, is_a: String, required: false

          def call
            result = CommandTower::Services::RateLimits::Check.call(
              key: "auth:password_check:ip:#{client_ip}:#{Time.now.to_i / 60}",
              ttl_seconds: 60
            )
            return if result.failure?
            return if result.data[:count] <= LIMIT_PER_MINUTE

            fail_rate_limited(result.data[:ttl])
          end

          private

          def fail_rate_limited(ttl)
            context.fail!(
              application_error: CommandTower::Errors::Auth::AuthRateLimitedError.new(
                retry_after_seconds: ttl.positive? ? ttl : nil
              )
            )
          end
        end
      end
    end
  end
end

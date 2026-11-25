# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module SignupRateLimits
        # Per-email ceiling on POST /auth/register attempts per hour (every attempt counts). The
        # key is an HMAC of the normalized email, so no email sits in Redis in plaintext.
        # Registration reveals whether an email is taken by design, so this bucket is what throttles
        # probing. A Redis failure fails open: the per-IP bucket still applies.
        class CheckRegisterEmail < CommandTower::Services::ApplicationService
          include LoginRateLimits::Enforcement

          WINDOW_SECONDS = 3600

          validate :email, is_a: String, required: true, sensitive: true

          def call
            return unless limits.register_attempts_per_email.positive?

            result = count_attempt
            return if result.failure? || result.data[:count] <= limits.register_attempts_per_email

            context.fail!(application_error: rate_limit_error(result.data[:ttl]))
          end

          private

          def count_attempt
            CommandTower::Services::RateLimits::Check.call(
              key: "auth:register:email:#{hmac_segment(email)}",
              ttl_seconds: WINDOW_SECONDS
            )
          end
        end
      end
    end
  end
end

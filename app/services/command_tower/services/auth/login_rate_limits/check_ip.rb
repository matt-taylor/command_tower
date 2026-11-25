# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module LoginRateLimits
        # Per-client-IP ceiling on login attempts (every attempt counts). A Redis
        # failure fails open: the attempt is counted in-process instead (see
        # FailOpen), and bcrypt cost plus the account lockout still throttle.
        class CheckIp < CommandTower::Services::ApplicationService
          include Enforcement

          validate :client_ip, is_a: String, required: true

          def call
            return unless limits.ip_attempts.positive?

            count, ttl = count_attempt
            return if count <= limits.ip_attempts

            context.fail!(application_error: rate_limit_error(ttl))
          end

          private

          def count_attempt
            key = "#{KEY_PREFIX}:ip:#{client_ip}"
            result = CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: limits.ip_window_seconds)
            return [result.data[:count], result.data[:ttl]] if result.success?

            FailOpen.publish(source: "ip")
            FailOpen.increment(key:, ttl_seconds: limits.ip_window_seconds)
          end
        end
      end
    end
  end
end

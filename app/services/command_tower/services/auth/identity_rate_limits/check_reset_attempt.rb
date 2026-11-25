# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module IdentityRateLimits
        # Per-client-IP ceiling on password reset token validate and redeem attempts
        # (every attempt counts). It stacks with the recovery-session buckets on send;
        # the stricter one answers first. A Redis failure fails open.
        class CheckResetAttempt < CommandTower::Services::ApplicationService
          include LoginRateLimits::Enforcement

          validate :client_ip, is_a: String

          def call
            return unless enabled?

            result = count_attempt
            return if result.failure? || result.data[:count] <= limits.reset_attempts_per_ip

            context.fail!(application_error: rate_limit_error(result.data[:ttl]))
          end

          private

          def enabled?
            client_ip.present? && limits.reset_attempts_per_ip.positive?
          end

          def count_attempt
            CommandTower::Services::RateLimits::Check.call(
              key: "auth:reset:ip:#{client_ip}",
              ttl_seconds: limits.reset_window_seconds
            )
          end
        end
      end
    end
  end
end

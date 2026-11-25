# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module IdentityRateLimits
        # Per-user ceiling on email verification code attempts (every attempt counts)
        # so a short code cannot be brute forced. A Redis failure fails open.
        class CheckVerifyAttempt < CommandTower::Services::ApplicationService
          include LoginRateLimits::Enforcement

          def self.key_for(user)
            "auth:verify:attempts:#{user.id}"
          end

          validate :user, is_a: User, required: true

          def call
            return unless limits.verify_attempts.positive?

            result = count_attempt
            return if result.failure? || result.data[:count] <= limits.verify_attempts

            context.fail!(application_error: rate_limit_error(result.data[:ttl]))
          end

          private

          def count_attempt
            CommandTower::Services::RateLimits::Check.call(
              key: self.class.key_for(user),
              ttl_seconds: limits.verify_window_seconds
            )
          end
        end
      end
    end
  end
end

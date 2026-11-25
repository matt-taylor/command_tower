# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module IdentityRateLimits
        # Decides whether a verification code request sends mail.
        #
        # A second request inside the quiet window is not an error: nothing is sent,
        # the caller gets quiet = true and resend_available_at. Only requests that
        # would send count toward the hourly cap, past which the answer is a 429.
        # A Redis failure fails open (send).
        class CheckVerificationSend < CommandTower::Services::ApplicationService
          include LoginRateLimits::Enforcement

          validate :user, is_a: User, required: true

          def call
            context.quiet = false
            context.resend_available_at = nil
            return if quiet_request?

            enforce_hourly_cap!
            context.resend_available_at = quiet_seconds.seconds.from_now if quiet_seconds.positive?
          end

          private

          def quiet_seconds
            limits.verify_send_quiet_seconds
          end

          def quiet_request?
            return false unless quiet_seconds.positive?

            quiet = count(key: "auth:verify:send:quiet:#{user.id}", ttl: quiet_seconds)
            return false unless quiet && quiet[:count] > 1

            context.quiet = true
            context.resend_available_at = [quiet[:ttl], 1].max.seconds.from_now
            true
          end

          def enforce_hourly_cap!
            return unless limits.verify_send_per_hour.positive?

            hourly = count(key: "auth:verify:send:hour:#{user.id}", ttl: 3600)
            return if hourly.nil? || hourly[:count] <= limits.verify_send_per_hour

            context.fail!(application_error: rate_limit_error(hourly[:ttl]))
          end

          def count(key:, ttl:)
            result = CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: ttl)
            result.failure? ? nil : result.data
          end
        end
      end
    end
  end
end

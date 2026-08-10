# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module SignupRateLimits
        # Counter vocabulary shared by the signup rate limit services. Each
        # service composes the buckets it cares about; this module owns how a
        # single bucket is incremented and how a breach is reported.
        module Enforcement
          private

          def limits
            CommandTower.config.signup_session.rate_limits
          end

          def enforce!(key:, ttl_seconds:, limit:, scope:)
            result = CommandTower::Services::RateLimits::Check.call(key: key, ttl_seconds: ttl_seconds)
            context.fail!(application_error: result.errors.first) if result.failure?
            return if result.data[:count] <= limit

            context.fail!(application_error: rate_limit_error(scope, result.data[:ttl]))
          end

          def rate_limit_error(scope, ttl)
            retry_after = ttl.positive? ? ttl : nil

            if scope == :session
              CommandTower::Errors::Auth::SignupSessionRateLimitError.new(retry_after_seconds: retry_after)
            else
              CommandTower::Errors::Auth::SignupIpRateLimitError.new(retry_after_seconds: retry_after)
            end
          end

          def minute_bucket
            Time.now.to_i / 60
          end

          def hour_bucket
            Time.now.to_i / 3600
          end

          def normalize_ip(client_ip)
            client_ip.to_s
          end
        end
      end
    end
  end
end

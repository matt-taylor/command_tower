# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module LoginRateLimits
        # Vocabulary shared by the login rate limit services: where the ceilings
        # live, how a subject becomes a Redis key segment, and how a breach is
        # reported.
        module Enforcement
          KEY_PREFIX = "auth:login"

          private

          def limits
            CommandTower.config.login.rate_limits
          end

          # Keyed HMAC so no email, username or user id sits in Redis in plaintext
          # and an unsalted hash cannot be reversed offline from a Redis dump.
          def hmac_segment(subject)
            OpenSSL::HMAC.hexdigest("SHA256", limits.lockout_hmac_key, subject.to_s)
          end

          def rate_limit_error(ttl)
            seconds = ttl.to_i
            CommandTower::Errors::Auth::AuthRateLimitedError.new(retry_after_seconds: seconds.positive? ? seconds : nil)
          end
        end
      end
    end
  end
end

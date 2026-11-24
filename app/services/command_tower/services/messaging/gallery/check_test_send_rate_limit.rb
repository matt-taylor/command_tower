# frozen_string_literal: true

module CommandTower
  module Services
    module Messaging
      module Gallery
        # Caps the gallery test send per real actor: 5 an hour and 20 a day. Each call counts one
        # attempt in both windows. A Redis error fails closed (the underlying InternalError).
        class CheckTestSendRateLimit < CommandTower::Services::ApplicationService
          WINDOWS = [
            { name: "hour", limit: 5, ttl_seconds: 3600 },
            { name: "day", limit: 20, ttl_seconds: 86_400 }
          ].freeze

          validate :actor_id, is_a: Integer, required: true

          def call
            WINDOWS.each { |window| enforce(window) }
          end

          private

          def enforce(window)
            result = count_attempt(window)
            context.fail!(application_error: result.errors.first) if result.failure?
            return if result.data[:count] <= window[:limit]

            context.fail!(application_error: rate_limited(result.data[:ttl]))
          end

          def count_attempt(window)
            CommandTower::Services::RateLimits::Check.call(
              key: "admin:messaging:gallery_test_send:#{window[:name]}:actor:#{actor_id}",
              ttl_seconds: window[:ttl_seconds]
            )
          end

          def rate_limited(ttl)
            CommandTower::Errors::Messaging::GalleryTestSendRateLimitError.new(
              retry_after_seconds: ttl.positive? ? ttl : nil
            )
          end
        end
      end
    end
  end
end

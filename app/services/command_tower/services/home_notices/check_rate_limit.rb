# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Rate limits `GET /me/home-notices` per user: `config.home_notices.rate_limit_per_minute`
      # requests in a 60 second fixed bucket (design D5).
      #
      # Fails open when Redis is unavailable: an outage must not hide must-see notices. The failure
      # publishes `command_tower.home_notices.rate_limiter_unavailable` (user id only).
      # Over the limit, the result fails with `Errors::HomeNotices::RateLimitError` carrying the
      # seconds until the bucket resets.
      class CheckRateLimit < CommandTower::Services::ApplicationService
        WINDOW_SECONDS = 60

        validate :user, is_a: User, required: true

        def call
          result = CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: WINDOW_SECONDS)
          return report_unavailable(result) if result.failure?
          return if result.data[:count] <= CommandTower.config.home_notices.rate_limit_per_minute

          ttl = result.data[:ttl]
          context.fail!(application_error: CommandTower::Errors::HomeNotices::RateLimitError.new(
            retry_after_seconds: ttl.positive? ? ttl : nil
          ))
        end

        private

        def key
          "home-notices:rate:get:#{user.id}:#{Time.now.to_i / WINDOW_SECONDS}"
        end

        def report_unavailable(result)
          error = result.errors.first
          CommandTower::Events.publish(category: :home_notices, name: "rate_limiter_unavailable",
                                       payload: { user_id: user.id, error_class: (error&.cause || error).class.name,
                                                  log_level: :error })
        end
      end
    end
  end
end

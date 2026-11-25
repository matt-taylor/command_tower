# frozen_string_literal: true

module CommandTower
  module Services
    module HomeNotices
      # Rate limits Home Notices requests per user in a 60 second fixed bucket (design D5):
      # - `bucket: :get` (default): `GET /me/home-notices`, `config.home_notices.rate_limit_per_minute`
      # - `bucket: :mutation`: impression, acknowledge and dismiss share one bucket,
      #   `config.home_notices.mutation_rate_limit_per_minute`
      #
      # Fails open when Redis is unavailable: an outage must not hide must-see notices. The failure
      # publishes `command_tower.home_notices.rate_limiter_unavailable` (user id only).
      # Over the limit, the result fails with `Errors::HomeNotices::RateLimitError` carrying the
      # seconds until the bucket resets.
      class CheckRateLimit < CommandTower::Services::ApplicationService
        WINDOW_SECONDS = 60

        validate :user, is_a: User, required: true
        validate :bucket, is_one: %i[get mutation], default: :get

        def call
          result = CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: WINDOW_SECONDS)
          return report_unavailable(result) if result.failure?
          return if result.data[:count] <= limit

          ttl = result.data[:ttl]
          context.fail!(application_error: CommandTower::Errors::HomeNotices::RateLimitError.new(
            retry_after_seconds: ttl.positive? ? ttl : nil
          ))
        end

        private

        def limit
          config = CommandTower.config.home_notices
          bucket == :mutation ? config.mutation_rate_limit_per_minute : config.rate_limit_per_minute
        end

        def key
          "home-notices:rate:#{bucket}:#{user.id}:#{Time.now.to_i / WINDOW_SECONDS}"
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

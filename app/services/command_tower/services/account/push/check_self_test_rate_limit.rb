# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module Push
        # Enforces Me push self-test rate limits via existing RateLimits::Check.
        # Ceiling and window come from config.messaging.expo composers — not hardcoded here.
        class CheckSelfTestRateLimit < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            expo = CommandTower.config.messaging.expo
            limit = expo.self_test_per_user_hour
            ttl_seconds = expo.self_test_window_seconds

            result = CommandTower::Services::RateLimits::Check.call(
              key: "me:push:self_test:user:#{user.id}",
              ttl_seconds:,
            )
            if result.failure?
              context.fail!(application_error: result.errors.first)
              return
            end

            count = result.data[:count]
            return if count <= limit

            ttl = result.data[:ttl]
            retry_after = ttl.positive? ? ttl : nil
            context.fail!(
              application_error: CommandTower::Errors::Account::PushTestRateLimitError.new(
                retry_after_seconds: retry_after,
              ),
            )
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Services
    module Account
      module ExperienceStates
        # Rate limits experience-state completion per user, in fixed buckets sized by
        # `config.registry.experience_states.complete_rate` (`limit` requests per `window` seconds).
        #
        # Fails open when Redis is unavailable: a limiter outage must not block completions. The
        # failure publishes `command_tower.experience_states.rate_limiter_unavailable` (user id only).
        # Over the limit, the result fails with `Errors::Account::ExperienceStateRateLimited`
        # carrying the seconds until the bucket resets.
        class CheckCompleteRateLimit < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            result = CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds: window)
            return report_unavailable(result) if result.failure?
            return if result.data[:count] <= rate[:limit]

            ttl = result.data[:ttl]
            context.fail!(application_error: CommandTower::Errors::Account::ExperienceStateRateLimited.new(
              retry_after_seconds: ttl.positive? ? ttl : nil
            ))
          end

          private

          def rate
            CommandTower.config.registry.experience_states.complete_rate
          end

          def window
            rate[:window]
          end

          def key
            "experience-states:complete:#{user.id}:#{Time.now.to_i / window}"
          end

          def report_unavailable(result)
            error = result.errors.first
            CommandTower::Events.publish(category: :experience_states, name: "rate_limiter_unavailable",
                                         payload: { user_id: user.id, error_class: (error&.cause || error).class.name,
                                                    log_level: :error })
          end
        end
      end
    end
  end
end

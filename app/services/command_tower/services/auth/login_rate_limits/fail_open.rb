# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module LoginRateLimits
        # Degraded mode for login rate limits when Redis is unavailable.
        #
        # Login never 500s and never locks everyone out because Redis is down: the
        # request is allowed, the failure is counted in `auth.rate_limit.fail_open`,
        # and a per-process counter keeps a coarse ceiling in place (it is not shared
        # across processes, so it only limits a single worker's view of one key).
        module FailOpen
          REDIS_ERRORS = [Redis::BaseError, Timeout::Error].freeze
          MAX_TRACKED_KEYS = 10_000

          WINDOWS = Concurrent::Map.new

          module_function

          # Counts one attempt for key in the in-process window. Returns [count, ttl].
          def increment(key:, ttl_seconds:)
            now = monotonic_now
            WINDOWS.clear if WINDOWS.size >= MAX_TRACKED_KEYS
            entry = WINDOWS.compute(key) do |current|
              if current.nil? || current[:expires_at] <= now
                { count: 1, expires_at: now + ttl_seconds }
              else
                { count: current[:count] + 1, expires_at: current[:expires_at] }
              end
            end
            [entry[:count], [(entry[:expires_at] - now).ceil, 1].max]
          end

          def publish(source:)
            CommandTower::Events.publish(category: :auth, name: "rate_limit.fail_open", payload: { source: source })
          end

          def reset!
            WINDOWS.clear
          end

          def monotonic_now
            Process.clock_gettime(Process::CLOCK_MONOTONIC)
          end
        end
      end
    end
  end
end

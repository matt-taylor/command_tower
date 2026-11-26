# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module LoginRateLimits
        # Soft per-account lockout for password login.
        #
        # The subject is the user id when the identifier resolves to an account (so
        # email and username share one counter), otherwise the normalized identifier
        # (so unknown identifiers lock exactly like real ones).
        #
        # Only failed attempts count. Counting, locking and the progressive level all
        # happen in one Lua script, so concurrent requests cannot each read "9" and
        # slip past the threshold, and a failure that lands while the account is
        # locked is not counted (hammering cannot extend a lock). Every lock expires.
        #
        # A Redis error or pool timeout fails open (nothing is locked) and is reported
        # through FailOpen; lockout state is shared, so there is no per-process fallback.
        class Lockout
          include Enforcement

          Result = Struct.new(:locked, :retry_after, keyword_init: true) do
            alias_method :locked?, :locked
          end

          RECORD_FAILURE_SCRIPT = <<~LUA
            local lock_ttl = redis.call('TTL', KEYS[2])
            if lock_ttl > 0 then
              return { 1, lock_ttl, 0 }
            end
            local count = redis.call('INCR', KEYS[1])
            if count == 1 then
              redis.call('EXPIRE', KEYS[1], tonumber(ARGV[1]))
            end
            if count < tonumber(ARGV[2]) then
              return { 0, 0, count }
            end
            local level = redis.call('INCR', KEYS[3])
            if level == 1 then
              redis.call('EXPIRE', KEYS[3], tonumber(ARGV[5]))
            end
            local duration = math.floor(math.min(tonumber(ARGV[3]) * (2 ^ (level - 1)), tonumber(ARGV[4])))
            redis.call('SET', KEYS[2], '1', 'NX', 'EX', duration)
            redis.call('DEL', KEYS[1])
            return { 1, duration, count }
          LUA

          NOT_LOCKED = Result.new(locked: false, retry_after: 0).freeze

          def self.subject_for(user:, identifier:)
            user ? "user:#{user.id}" : "identifier:#{identifier.to_s.strip.downcase}"
          end

          def initialize(subject:)
            @subject = subject
          end

          # Reads the lock key without counting anything.
          def status
            return NOT_LOCKED unless enabled?

            peek = CommandTower::Services::RateLimits::Peek.call(key: lock_key)
            if peek.failure?
              FailOpen.publish(source: "lockout")
              return NOT_LOCKED
            end
            return NOT_LOCKED if peek.data[:count].zero? || peek.data[:ttl].zero?

            Result.new(locked: true, retry_after: peek.data[:ttl])
          end

          # Counts one failed attempt. Locked is true when the account is locked after
          # this call (already locked, or this failure tripped the lock).
          def record_failure
            return NOT_LOCKED unless enabled?

            locked, retry_after, count = CommandTower::RedisConnection.with do |redis|
              redis.eval(RECORD_FAILURE_SCRIPT, keys: [fail_key, lock_key, level_key], argv: script_args)
            end
            publish_started if locked.to_i == 1 && count.to_i.positive?
            Result.new(locked: locked.to_i == 1, retry_after: retry_after.to_i)
          rescue *FailOpen::REDIS_ERRORS
            FailOpen.publish(source: "lockout")
            NOT_LOCKED
          end

          # A successful login or password reset ends the streak. A reset also drops the
          # lock and the repeat-lock level, so the person who just proved ownership of
          # the mailbox is not held out.
          def clear(lock_and_level: false)
            keys = lock_and_level ? [fail_key, lock_key, level_key] : [fail_key]
            keys.each { |key| CommandTower::Services::RateLimits::Clear.call(key:) }
          end

          private

          def enabled?
            limits.account_failures.positive?
          end

          def fail_key
            "#{KEY_PREFIX}:fail:#{hmac_segment(@subject)}"
          end

          def lock_key
            "#{KEY_PREFIX}:lock:#{hmac_segment(@subject)}"
          end

          def level_key
            "#{KEY_PREFIX}:level:#{hmac_segment(@subject)}"
          end

          def script_args
            [
              limits.account_window_seconds,
              limits.account_failures,
              limits.lock_base_seconds,
              limits.lock_max_seconds,
              limits.lock_level_window_seconds
            ]
          end

          def publish_started
            CommandTower::Events.publish(category: :auth, name: "lockout.started")
          end
        end
      end
    end
  end
end

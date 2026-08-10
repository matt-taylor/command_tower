# frozen_string_literal: true

module CommandTower
  module Services
    module RateLimits
      class Check < CommandTower::Services::ApplicationService
        INCREMENT_SCRIPT = <<~LUA
          local count = redis.call('INCR', KEYS[1])
          if count == 1 then
            redis.call('EXPIRE', KEYS[1], tonumber(ARGV[1]))
          end
          return { count, redis.call('TTL', KEYS[1]) }
        LUA

        validate :key, is_a: String, required: true
        validate :ttl_seconds, is_a: Integer, required: true

        def call
          count, ttl = CommandTower::RedisConnection.with do |redis|
            redis.eval(INCREMENT_SCRIPT, keys: [key], argv: [ttl_seconds])
          end

          context.count = count.to_i
          context.ttl = ttl.to_i
        rescue Redis::BaseError => e
          context.fail!(application_error: CommandTower::Errors::InternalError.new(cause: e))
        end
      end
    end
  end
end

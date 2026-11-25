# frozen_string_literal: true

module CommandTower
  module Services
    module RateLimits
      # Reads a rate-limit counter without incrementing it.
      class Peek < CommandTower::Services::ApplicationService
        validate :key, is_a: String, required: true

        def call
          count, ttl = CommandTower::RedisConnection.with do |redis|
            [redis.get(key), redis.ttl(key)]
          end

          context.count = count.to_i
          context.ttl = [ttl.to_i, 0].max
        rescue Redis::BaseError, Timeout::Error => e
          context.fail!(application_error: CommandTower::Errors::InternalError.new(cause: e))
        end
      end
    end
  end
end

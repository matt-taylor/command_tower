# frozen_string_literal: true

module CommandTower
  module Services
    module RateLimits
      # Deletes a rate-limit counter so the next Check starts a fresh window.
      class Clear < CommandTower::Services::ApplicationService
        validate :key, is_a: String, required: true

        def call
          CommandTower::RedisConnection.with { |redis| redis.del(key) }
        rescue Redis::BaseError, Timeout::Error => e
          context.fail!(application_error: CommandTower::Errors::InternalError.new(cause: e))
        end
      end
    end
  end
end

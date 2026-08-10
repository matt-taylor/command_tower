# frozen_string_literal: true

require "redis"

module CommandTower
  module RedisConnection
    module_function

    def current
      @current ||= Redis.new(url: ENV.fetch("REDIS_URL"))
    end

    def with
      yield current
    end

    def reset!
      @current = nil
    end
  end
end

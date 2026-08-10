# frozen_string_literal: true

module CommandTower
  module Clients
    module Transport
      FaradayConfig = Data.define(:pool_size, :idle_timeout, :open_timeout, :timeout) do
        DEFAULT_POOL_SIZE = 5
        DEFAULT_IDLE_TIMEOUT = 30
        DEFAULT_OPEN_TIMEOUT = 5
        DEFAULT_TIMEOUT = 30

        # pool_size — ConnectionPool size (concurrent Faraday::Connection checkouts)
        # idle_timeout — net_http_persistent idle timeout per pooled connection
        # open_timeout — Faraday open timeout and ConnectionPool checkout timeout
        # timeout — default per-request Faraday timeout

        def self.defaults
          new(
            pool_size: DEFAULT_POOL_SIZE,
            idle_timeout: DEFAULT_IDLE_TIMEOUT,
            open_timeout: DEFAULT_OPEN_TIMEOUT,
            timeout: DEFAULT_TIMEOUT
          )
        end

        def self.from_env
          new(
            pool_size: integer_env("CLIENTS_HTTP_POOL_SIZE", DEFAULT_POOL_SIZE),
            idle_timeout: integer_env("CLIENTS_HTTP_IDLE_TIMEOUT", DEFAULT_IDLE_TIMEOUT),
            open_timeout: integer_env("CLIENTS_HTTP_OPEN_TIMEOUT", DEFAULT_OPEN_TIMEOUT),
            timeout: integer_env("CLIENTS_HTTP_TIMEOUT", DEFAULT_TIMEOUT)
          )
        end

        def self.integer_env(key, default)
          value = ENV[key]
          return default if value.nil? || value.strip.empty?

          Integer(value)
        end
        private_class_method :integer_env
      end
    end
  end
end

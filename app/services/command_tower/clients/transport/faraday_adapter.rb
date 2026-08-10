# frozen_string_literal: true

require "json"
require "faraday"
require "faraday/net_http_persistent"
require "connection_pool"

module CommandTower
  module Clients
    module Transport
      class FaradayAdapter
        attr_reader :config, :pool

        def initialize(config: FaradayConfig.defaults, connection: nil, **overrides)
          @config = resolve_config(config, overrides)
          @pool = build_pool(connection)
        end

        def call(request)
          unless request.is_a?(Request)
            raise Errors::ConfigurationError,
                  "request must be a #{Request.name}"
          end

          started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          url = merge_url_and_query(request.url, request.query)
          body, headers = encode_body(request.body, request.headers)
          timeout = request.timeout || config.timeout

          response = with_connection do |connection|
            connection.run_request(request.method, url, body, headers) do |req|
              req.options.timeout = timeout
              req.options.open_timeout = config.open_timeout
            end
          end

          Response.build(
            status: response.status,
            headers: response.headers.to_h,
            body: response.body,
            duration_ms: elapsed_ms(started_at)
          )
        rescue Faraday::TimeoutError => e
          raise Error.new(e.message.presence || "request timed out", cause: e)
        rescue Faraday::ConnectionFailed => e
          raise Error.new(e.message.presence || "connection failed", cause: e)
        rescue ConnectionPool::TimeoutError => e
          raise Error.new(e.message.presence || "connection pool timeout", cause: e)
        end

        private

        def resolve_config(config, overrides)
          base = config || FaradayConfig.defaults
          return base if overrides.empty?

          FaradayConfig.new(
            pool_size: overrides.fetch(:pool_size, base.pool_size),
            idle_timeout: overrides.fetch(:idle_timeout, base.idle_timeout),
            open_timeout: overrides.fetch(:open_timeout, base.open_timeout),
            timeout: overrides.fetch(:timeout, base.timeout)
          )
        end

        def build_pool(connection)
          if connection
            ConnectionPool.new(size: 1, timeout: config.open_timeout) { connection }
          else
            ConnectionPool.new(size: config.pool_size, timeout: config.open_timeout) do
              build_persistent_connection(config)
            end
          end
        end

        def with_connection(&block)
          pool.with(&block)
        end

        def build_persistent_connection(config)
          Faraday.new do |faraday|
            # One socket-management context per pooled Faraday::Connection;
            # concurrency across threads is provided by ConnectionPool.
            faraday.adapter :net_http_persistent, pool_size: 1 do |http|
              http.idle_timeout = config.idle_timeout
            end
          end
        end

        def merge_url_and_query(url, query)
          uri = URI.parse(url)
          existing = URI.decode_www_form(uri.query.to_s)
          extra = normalize_query(query).flat_map do |key, value|
            Array(value).map { |item| [ key.to_s, item.to_s ] }
          end
          combined = existing + extra
          uri.query = combined.empty? ? nil : URI.encode_www_form(combined)
          uri.to_s
        end

        def normalize_query(query)
          query.to_h
        end

        def encode_body(body, headers)
          normalized_headers = headers.to_h.transform_keys(&:to_s)

          case body
          when Hash, Array
            encoded = JSON.generate(body)
            unless content_type_present?(normalized_headers)
              normalized_headers = normalized_headers.merge("Content-Type" => "application/json")
            end
            [ encoded, normalized_headers ]
          else
            [ body, normalized_headers ]
          end
        end

        def content_type_present?(headers)
          headers.keys.any? { |key| key.downcase == "content-type" }
        end

        def elapsed_ms(started_at)
          ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        end
      end
    end
  end
end

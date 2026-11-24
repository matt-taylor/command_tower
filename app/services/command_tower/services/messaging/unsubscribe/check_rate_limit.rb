# frozen_string_literal: true

require "digest"

module CommandTower
  module Services
    module Messaging
      module Unsubscribe
        # Rate limits the unauthenticated one-click unsubscribe endpoint.
        #
        # - Per token: TOKEN_LIMIT requests per TOKEN_WINDOW_SECONDS. The key is the SHA-256 digest of
        #   the token, so the token itself never reaches Redis. This is the main limit: a mail client
        #   or scanner replays one token, an attacker guesses many.
        # - Per client IP: IP_LIMIT requests per IP_WINDOW_SECONDS. Deliberately high, because many
        #   recipients share a mail gateway or NAT. The IP is `request.remote_ip`, which honours
        #   `X-Forwarded-For` only behind the host's configured `trusted_proxies` (Services::Auth::ClientIpResolver).
        # - Redis failure: fail open. Unsubscribe is a compliance action and the token is a signed,
        #   unforgeable value, so an outage must not block a recipient from opting out.
        class CheckRateLimit < CommandTower::Services::ApplicationService
          TOKEN_LIMIT = 10
          TOKEN_WINDOW_SECONDS = 60
          IP_LIMIT = 120
          IP_WINDOW_SECONDS = 60

          validate :token, is_a: String, required: true
          validate :client_ip, is_a: String, required: true

          def call
            enforce!(key: "messaging-unsubscribe:rate:token:#{Digest::SHA256.hexdigest(token)}:#{bucket(TOKEN_WINDOW_SECONDS)}",
                     ttl_seconds: TOKEN_WINDOW_SECONDS, limit: TOKEN_LIMIT)
            enforce!(key: "messaging-unsubscribe:rate:ip:#{client_ip}:#{bucket(IP_WINDOW_SECONDS)}",
                     ttl_seconds: IP_WINDOW_SECONDS, limit: IP_LIMIT)
          end

          private

          def enforce!(key:, ttl_seconds:, limit:)
            result = CommandTower::Services::RateLimits::Check.call(key:, ttl_seconds:)
            return if result.failure?
            return if result.data[:count] <= limit

            ttl = result.data[:ttl]
            context.fail!(
              application_error: CommandTower::Errors::Messaging::UnsubscribeRateLimitError.new(
                retry_after_seconds: ttl.positive? ? ttl : nil
              )
            )
          end

          def bucket(window_seconds)
            Time.now.to_i / window_seconds
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/password_recovery_session/rate_limits"

module CommandTower
  module Configuration
    module PasswordRecoverySession
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        # Claim defaults are wire contract: changing them invalidates tokens already
        # issued to password recovery clients.
        add_composer :issuer,
          desc: "`iss` claim stamped on password recovery session tokens",
          allowed: String,
          default: "command_tower:password-recovery"

        add_composer :audience,
          desc: "`aud` claim stamped on password recovery session tokens",
          allowed: String,
          default: "password-recovery-send"

        add_composer :purpose,
          desc: "`purpose` claim stamped on password recovery session tokens",
          allowed: String,
          default: "password-recovery"

        add_composer :ttl,
          desc: "How long an issued password recovery session token remains valid",
          allowed: ActiveSupport::Duration,
          default: 15.minutes

        add_composer :cleanup_buffer_seconds,
          desc: "Extra seconds added to per-session rate limit key TTLs so counters outlive the token",
          allowed: Integer,
          default: 300

        # Host applications must supply this (config or PASSWORD_RECOVERY_SESSION_JWT_SECRET).
        # Defaulting to "" rather than raising keeps gem load side-effect free; use
        # `configured?` to fail closed at the point of use.
        add_composer :jwt_secret,
          desc: "HS256 secret used to sign password recovery session tokens. Host must set this outside of test",
          allowed: String,
          default: (
            ENV["PASSWORD_RECOVERY_SESSION_JWT_SECRET"].presence ||
              (defined?(Rails) && Rails.env.test? ? "test-password-recovery-session-jwt-secret" : "")
          )

        add_composer :rate_limits,
          desc: "Password recovery rate limit ceilings applied per recovery session and per client IP",
          allowed: RateLimits,
          default: RateLimits.new

        def configured?
          jwt_secret.present?
        end
      end
    end
  end
end

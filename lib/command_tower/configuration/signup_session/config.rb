# frozen_string_literal: true

require "class_composer"
require "command_tower/configuration/signup_session/email_availability"
require "command_tower/configuration/signup_session/rate_limits"

module CommandTower
  module Configuration
    module SignupSession
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer_blocking :email_availability,
          desc: "Route gate for modern email availability HTTP (GET /auth/email/availability)",
          composer_class: EmailAvailability,
          enable_attr: :enable

        # Claim defaults are wire contract: changing them invalidates tokens already
        # issued to signup clients.
        add_composer :issuer,
          desc: "`iss` claim stamped on signup session tokens",
          allowed: String,
          default: "command_tower:signup"

        add_composer :audience,
          desc: "`aud` claim stamped on signup session tokens",
          allowed: String,
          default: "signup-availability"

        add_composer :purpose,
          desc: "`purpose` claim stamped on signup session tokens",
          allowed: String,
          default: "signup"

        add_composer :ttl,
          desc: "How long an issued signup session token remains valid",
          allowed: ActiveSupport::Duration,
          default: 20.minutes

        add_composer :cleanup_buffer_seconds,
          desc: "Extra seconds added to per-session rate limit key TTLs so counters outlive the token",
          allowed: Integer,
          default: 300

        # Host applications must supply this (config or SIGNUP_SESSION_JWT_SECRET).
        # Defaulting to "" rather than raising keeps gem load side-effect free; use
        # `configured?` to fail closed at the point of use.
        add_composer :jwt_secret,
          desc: "HS256 secret used to sign signup session tokens. Host must set this outside of test",
          allowed: String,
          default: (
            ENV["SIGNUP_SESSION_JWT_SECRET"].presence ||
              (defined?(Rails) && Rails.env.test? ? "test-signup-session-jwt-secret" : "")
          )

        add_composer :rate_limits,
          desc: "Signup rate limit ceilings applied per signup session and per client IP",
          allowed: RateLimits,
          default: RateLimits.new

        def configured?
          jwt_secret.present?
        end
      end
    end
  end
end

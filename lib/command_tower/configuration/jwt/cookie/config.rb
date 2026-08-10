# frozen_string_literal: true

require "command_tower/configuration/jwt/cookie/csrf/config"

module CommandTower
  module Configuration
    module Jwt
      module Cookie
        class Config < ::CommandTower::Configuration::Base
          include ClassComposer::Generator

          add_composer :enabled,
            desc: "Enable HttpOnly cookie support for JWT tokens. When disabled, cookies are never set, read, or refreshed",
            allowed: [TrueClass, FalseClass],
            default: false

          add_composer :name,
            desc: "Name of the JWT cookie",
            allowed: String,
            default: "ct_jwt"

          add_composer :same_site,
            desc: "SameSite attribute for the cookie (:lax, :strict, or :none)",
            allowed: Symbol,
            default: :lax

          add_composer :secure,
            desc: "Secure flag for the cookie (HTTPS only). Defaults to false in development, true in production",
            allowed: [TrueClass, FalseClass],
            default: false

          add_composer :httponly,
            desc: "HttpOnly flag for the cookie (prevents JavaScript access)",
            allowed: [TrueClass, FalseClass],
            default: true

          add_composer :path,
            desc: "Path for the cookie",
            allowed: String,
            default: "/"

          add_composer :domain,
            desc: "Domain for the cookie (nil means host-only)",
            allowed: [String, NilClass],
            default: nil

          add_composer :ttl,
            desc: "Time to live for the cookie (defaults to JWT TTL)",
            allowed: ActiveSupport::Duration,
            default: 7.days

          add_composer_blocking :csrf,
            desc: "Double-submit CSRF protection configuration for cookie-authenticated requests",
            composer_class: Csrf::Config,
            enable_attr: :enabled

          def enabled?
            enabled
          end
        end
      end
    end
  end
end

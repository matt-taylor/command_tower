# frozen_string_literal: true

module CommandTower
  module Configuration
    module Jwt
      module Cookie
        module Csrf
          class Config < ::CommandTower::Configuration::Base
            include ClassComposer::Generator

            add_composer :enabled,
              desc: "Enable double-submit CSRF protection for cookie-authenticated requests",
              allowed: [TrueClass, FalseClass],
              default: false

            add_composer :cookie_name,
              desc: "Name of the CSRF token cookie (must NOT be HttpOnly)",
              allowed: String,
              default: "ct_csrf"

            add_composer :header_name,
              desc: "Name of the CSRF token header",
              allowed: String,
              default: "X-CSRF-Token"

            add_composer :rotate_on_login,
              desc: "Rotate CSRF token on login",
              allowed: [TrueClass, FalseClass],
              default: true

            add_composer :rotate_on_reset,
              desc: "Rotate CSRF token when JWT token is reset",
              allowed: [TrueClass, FalseClass],
              default: true

            # Note: rotate_on_logout removed - logout always clears CSRF cookie (not configurable)

            # Cookie attributes (default to nil to inherit from JWT cookie settings)
            add_composer :same_site,
              desc: "SameSite attribute for CSRF cookie (nil inherits from JWT cookie)",
              allowed: [Symbol, NilClass],
              default: nil

            add_composer :secure,
              desc: "Secure flag for CSRF cookie (nil inherits from JWT cookie)",
              allowed: [TrueClass, FalseClass, NilClass],
              default: nil

            add_composer :path,
              desc: "Path for the CSRF cookie (nil inherits from JWT cookie)",
              allowed: [String, NilClass],
              default: nil

            add_composer :domain,
              desc: "Domain for the CSRF cookie (nil inherits from JWT cookie)",
              allowed: [String, NilClass],
              default: nil

            add_composer :ttl,
              desc: "Time to live for the CSRF cookie",
              allowed: ActiveSupport::Duration,
              default: 7.days

            def enabled?
              enabled
            end
          end
        end
      end
    end
  end
end

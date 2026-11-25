# frozen_string_literal: true

require "command_tower/configuration/jwt/cookie/config"

module CommandTower
  module Configuration
    module Jwt
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        DEFAULT_HMAC_SECRET = "Thi$IsASeccretIwi::CH&ang3"
        ALLOW_INSECURE_ENV = "COMMAND_TOWER_ALLOW_INSECURE_JWT_SECRET"

        add_composer :ttl,
          desc: "Default TTL on how long the token is valid for",
          allowed: ActiveSupport::Duration,
          default: 7.days

        add_composer :hmac_secret,
          desc: "HMAC is the only algorithm supported. This is the secret key to encrypt he JWT token",
          allowed: String,
          default: ENV.fetch("SECRET_KEY_BASE", DEFAULT_HMAC_SECRET),
          default_shown: "ENV.fetch(\"SECRET_KEY_BASE\",\"Thi$IsASeccretIwi::CH&ang3\")"

        add_composer :allow_insecure_default_secret,
          desc: "Escape hatch: allow non-local boot with a blank or default hmac_secret. Temporary use only",
          allowed: [TrueClass, FalseClass],
          default: ENV.fetch(ALLOW_INSECURE_ENV, "false") == "true",
          default_shown: "ENV.fetch(\"#{ALLOW_INSECURE_ENV}\", \"false\") == \"true\""

        def insecure_hmac_secret?
          secret = hmac_secret.to_s
          secret.strip.empty? || secret == DEFAULT_HMAC_SECRET
        end

        # Raises outside local environments when the secret is blank or the published default.
        def validate_secret!(local: Rails.env.local?)
          return if local || allow_insecure_default_secret
          return unless insecure_hmac_secret?

          raise CommandTower::Errors::InsecureJwtSecretError
        end

        add_composer_blocking :cookie,
          desc: "HttpOnly cookie configuration for JWT token persistence",
          composer_class: Cookie::Config,
          enable_attr: :enabled
      end
    end
  end
end

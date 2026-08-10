# frozen_string_literal: true

require "command_tower/configuration/jwt/cookie/config"

module CommandTower
  module Configuration
    module Jwt
      class Config < ::CommandTower::Configuration::Base
        include ClassComposer::Generator

        add_composer :ttl,
          desc: "Default TTL on how long the token is valid for",
          allowed: ActiveSupport::Duration,
          default: 7.days

        add_composer :hmac_secret,
          desc: "HMAC is the only algorithm supported. This is the secret key to encrypt he JWT token",
          allowed: String,
          default: ENV.fetch("SECRET_KEY_BASE","Thi$IsASeccretIwi::CH&ang3"),
          default_shown: "ENV.fetch(\"SECRET_KEY_BASE\",\"Thi$IsASeccretIwi::CH&ang3\")"

        add_composer_blocking :cookie,
          desc: "HttpOnly cookie configuration for JWT token persistence",
          composer_class: Cookie::Config,
          enable_attr: :enabled
      end
    end
  end
end

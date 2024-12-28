# frozen_string_literal: true

module ApiEngineBase
  module Configuration
    module Jwt
      class Config < ::ApiEngineBase::Configuration::Base
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
      end
    end
  end
end

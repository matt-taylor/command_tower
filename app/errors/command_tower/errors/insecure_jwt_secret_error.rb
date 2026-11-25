# frozen_string_literal: true

module CommandTower
  module Errors
    class InsecureJwtSecretError < ApplicationError
      def code
        "insecure_jwt_secret"
      end

      def message
        "config.jwt.hmac_secret is blank or the published default. Set a private secret " \
          "(for example ENV SECRET_KEY_BASE) or, only as a temporary escape hatch, " \
          "config.jwt.allow_insecure_default_secret = true " \
          "(ENV #{CommandTower::Configuration::Jwt::Config::ALLOW_INSECURE_ENV})."
      end

      def log_level
        :error
      end
    end
  end
end

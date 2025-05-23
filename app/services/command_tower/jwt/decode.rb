# frozen_string_literal: true

require "jwt"

module CommandTower::Jwt
  class Decode < CommandTower::ServiceBase

    validate :token, is_a: String, required: true, sensitive: true

    def call
      data = JWT.decode(token, CommandTower.config.jwt.hmac_secret, true, { algorithm: "HS256" })

      context.payload = data[0].with_indifferent_access
      context.headers = data[1].with_indifferent_access
    rescue JWT::DecodeError => e
      log_error(e)

      context.fail!(msg: "Invalid Token")
    end
  end
end

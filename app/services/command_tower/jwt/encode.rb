# frozen_string_literal: true

require "jwt"

module CommandTower::Jwt
  class Encode
    ALGORITHM = "HS256"

    def self.call(payload:, header: nil)
      JWT.encode(payload, CommandTower.config.jwt.hmac_secret, ALGORITHM, header || {})
    end
  end
end

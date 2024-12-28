# frozen_string_literal: true

require "jwt"

module ApiEngineBase::Jwt
  class Encode < ApiEngineBase::ServiceBase

    validate :payload, is_a: Hash, required: true
    validate :header, is_a: Hash, required: false

    def call
      context.token = JWT.encode(payload, ApiEngineBase.config.jwt.hmac_secret, "HS256", header || {})
    end
  end
end

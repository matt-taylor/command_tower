# frozen_string_literal: true

require "jwt"

module CommandTower::Jwt
  class Decode
    ALGORITHM = "HS256"

    DecodeOutcome = Data.define(:success, :payload, :headers, :msg) do
      def self.success(payload:, headers: nil)
        new(success: true, payload:, headers:, msg: nil)
      end

      def self.failure(msg:)
        new(success: false, payload: nil, headers: nil, msg:)
      end

      def success?
        success
      end

      def failure?
        !success
      end
    end

    def self.call(token:)
      data = JWT.decode(token, CommandTower.config.jwt.hmac_secret, true, { algorithm: ALGORITHM })

      DecodeOutcome.success(
        payload: data[0].with_indifferent_access,
        headers: data[1].with_indifferent_access
      )
    rescue JWT::DecodeError => e
      Rails.logger.warn { "[#{name}] Failed to decode token: #{e.class.name}" }

      DecodeOutcome.failure(msg: "Invalid Token")
    end
  end
end

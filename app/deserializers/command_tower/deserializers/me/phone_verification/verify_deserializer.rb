# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      module PhoneVerification
        class VerifyDeserializer
          Result = Struct.new(:success?, :input, :errors, keyword_init: true)
          Input = Struct.new(:code, keyword_init: true)

          def self.call(params)
            raw = params[:code].presence || params.dig(:phone_verification, :code).presence
            code = raw.to_s.strip

            if code.blank?
              return Result.new(
                success?: false,
                input: nil,
                errors: { code: "is required" }
              )
            end

            Result.new(success?: true, input: Input.new(code:), errors: {})
          end
        end
      end
    end
  end
end

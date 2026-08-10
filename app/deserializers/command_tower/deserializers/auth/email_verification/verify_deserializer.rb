# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      module EmailVerification
        class VerifyDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:code)

          def call(params)
            code = params[:code].to_s.strip

            return failure(errors: { message: "missing_code" }) if code.blank?

            success(Input.new(code:))
          end
        end
      end
    end
  end
end

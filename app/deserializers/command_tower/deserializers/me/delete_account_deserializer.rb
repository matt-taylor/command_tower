# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      class DeleteAccountDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:password)

        def call(params)
          password = params[:password]

          if blank?(password)
            return failure(errors: { message: "missing_required_fields" })
          end

          unless password.is_a?(String)
            return failure(errors: { message: "invalid_field_types" })
          end

          success(Input.new(password:))
        end

        private

        def blank?(value)
          value.nil? || (value.is_a?(String) && value.strip.empty?)
        end
      end
    end
  end
end

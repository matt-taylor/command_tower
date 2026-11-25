# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      # The password is sensitive: it is not stripped (whitespace counts toward length) and is
      # never echoed in errors.
      class PasswordCheckDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:password)

        def call(params)
          raw = fetch_param(params, :password).value
          return failure(errors: { message: "missing_password" }) if raw.nil? || raw == ""
          return failure(errors: { message: "invalid_field_types" }) unless raw.is_a?(String)

          success(Input.new(password: raw))
        end
      end
    end
  end
end

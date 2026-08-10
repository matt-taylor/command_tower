# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      module PlainText
        class LoginDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:identifier, :password)

          def call(params)
            identifier = params[:identifier].to_s.strip
            password = params[:password].to_s.strip

            if identifier.blank? || password.blank?
              return failure(errors: { message: "invalid_credentials" })
            end

            success(Input.new(identifier:, password:))
          end
        end
      end
    end
  end
end

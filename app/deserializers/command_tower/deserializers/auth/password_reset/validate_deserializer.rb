# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      module PasswordReset
        class ValidateDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:token, :email)

          def call(params)
            token = params[:token].to_s.strip
            return failure(errors: { token: "Token is required" }) if token.blank?

            email = params[:email].to_s.strip.downcase
            email = nil if email.blank?

            success(Input.new(token:, email:))
          end
        end
      end
    end
  end
end

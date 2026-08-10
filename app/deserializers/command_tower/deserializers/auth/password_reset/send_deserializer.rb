# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      module PasswordReset
        class SendDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:email)

          def call(params)
            email = params[:email].to_s.strip.downcase

            return failure(errors: { email: "Email is required" }) if email.blank?

            success(Input.new(email:))
          end
        end
      end
    end
  end
end

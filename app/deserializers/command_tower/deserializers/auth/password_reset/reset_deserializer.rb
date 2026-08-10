# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Auth
      module PasswordReset
        class ResetDeserializer < CommandTower::Deserializers::ApplicationDeserializer
          Input = Data.define(:token, :password, :password_confirmation, :email)

          def call(params)
            token = params[:token].to_s.strip
            password = params[:password].to_s
            password_confirmation = params[:passwordConfirmation].to_s.presence || params[:password_confirmation].to_s

            errors = {}
            errors[:token] = "Token is required" if token.blank?
            errors[:password] = "Password is required" if password.blank?
            errors[:passwordConfirmation] = "Password confirmation is required" if password_confirmation.blank?

            return failure(errors:) if errors.any?

            email = params[:email].to_s.strip.downcase
            email = nil if email.blank?

            success(Input.new(token:, password:, password_confirmation:, email:))
          end
        end
      end
    end
  end
end

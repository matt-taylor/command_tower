# frozen_string_literal: true

module CommandTower
  module Deserializers
    module Me
      # Transport-only: required fields, camelCase/snake_case, blank detection.
      # LoginStrategy owns password policy, confirmation match, and current-password check.
      class ChangePasswordDeserializer < CommandTower::Deserializers::ApplicationDeserializer
        Input = Data.define(:current_password, :password, :password_confirmation)

        def call(params)
          current_password = params[:current_password] || params[:currentPassword]
          password = params[:password]
          password_confirmation = params[:password_confirmation] || params[:passwordConfirmation]

          if blank?(current_password) || blank?(password) || blank?(password_confirmation)
            return failure(errors: { message: "missing_required_fields" })
          end

          unless current_password.is_a?(String) && password.is_a?(String) && password_confirmation.is_a?(String)
            return failure(errors: { message: "invalid_field_types" })
          end

          success(
            Input.new(
              current_password: current_password,
              password: password,
              password_confirmation: password_confirmation
            )
          )
        end

        private

        def blank?(value)
          value.nil? || (value.is_a?(String) && value.strip.empty?)
        end
      end
    end
  end
end

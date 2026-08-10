# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordReset
        # Consumes a reset token and replaces the account password.
        class Reset < CommandTower::Services::ApplicationService
          include TokenVerification

          RESET_MESSAGE = "Password has been successfully reset"
          CONFIRMATION_MISMATCH = "Password and confirmation do not match"

          validate :token, is_a: String, required: true, sensitive: true
          validate :password, is_a: String, required: true, sensitive: true
          validate :password_confirmation, is_a: String, required: true, sensitive: true
          validate :email, is_a: String, required: false, sensitive: true

          def call
            reject!(password_confirmation: CONFIRMATION_MISMATCH) unless password == password_confirmation
            reject!(password: password_length_message) unless password_length_valid?

            require_email!

            redemption = redeem_token!(access_count: true)
            user = redemption.user
            match_email!(token_user: user)

            user.password = password
            user.password_confirmation = password_confirmation

            unless user.save
              log_error("Failed to update the password for user [#{user.id}]")
              reject!(user.errors.to_hash.transform_values { Array(_1).join(", ") })
            end

            log_info("Password reset completed for user [#{user.id}]")
            context.message = RESET_MESSAGE
          end

          private

          def plain_text_configuration
            CommandTower.config.login.plain_text
          end

          def password_length_valid?
            length = password.length
            length >= plain_text_configuration.password_length_min &&
              length <= plain_text_configuration.password_length_max
          end

          def password_length_message
            "Password length must be between #{plain_text_configuration.password_length_min} " \
              "and #{plain_text_configuration.password_length_max} characters"
          end

          def reject!(details)
            context.fail!(application_error: CommandTower::Errors::ValidationError.new(details:))
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::PasswordReset
  class Reset < CommandTower::ServiceBase
    include Helper

    on_argument_validation :fail_early

    validate :token, is_a: String, required: true, sensitive: true
    validate :email, is_a: String, required: false
    validate :password, is_a: String, required: true, sensitive: true
    validate :password_confirmation, is_a: String, required: true, sensitive: true

    def call
      # Validate password confirmation matches
      unless password == password_confirmation
        inline_argument_failure!(errors: { password_confirmation: "Password and confirmation do not match" })
        return
      end

      # Validate password length
      password_config = CommandTower.config.login.plain_text
      if password.length < password_config.password_length_min || password.length > password_config.password_length_max
        inline_argument_failure!(errors: { password: "Password length must be between #{password_config.password_length_min} and #{password_config.password_length_max} characters" })
        return
      end

      validate_email_required!
      return if context.failure?

      verify_result = validate_token!
      return if context.failure?

      user = get_user_from_token!(verify_result)
      return if context.failure?

      validate_email_match!(token_user: user)
      return if context.failure?

      log_info("Password reset token verified successfully for user [#{user.id}]")

      # Update user password
      user.password = password
      user.password_confirmation = password_confirmation

      if user.save
        log_info("Password reset successfully completed for user [#{user.id}]")
        context.message = "Password has been successfully reset"
      else
        log_error("Failed to update password for user [#{user.id}]: #{user.errors.full_messages.join(', ')}")
        inline_argument_failure!(errors: user.errors)
      end
    end

    def access_count
      true
    end
  end
end

# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::PasswordReset
  class Send < CommandTower::ServiceBase
    on_argument_validation :fail_early

    validate :email, is_a: String, required: true

    def call
      # Validate email format
      unless email =~ URI::MailTo::EMAIL_REGEXP
        inline_argument_failure!(errors: { email: "Invalid email address" })
        return
      end

      # Find user by email (silently, no error if not found)
      user = User.find_by(email: email.downcase.strip)

      if user.nil?
        log_info("Password reset requested for email that doesn't exist: #{email.downcase.strip}")
        context.message = "If an account exists with that email, a password reset link has been sent."
        return
      end

      log_info("Password reset requested for user [#{user.id}] with email: #{user.email}")

      # Generate token using Secrets::Generate
      result = CommandTower::Secrets::Generate.(
        user: user,
        secret_length: password_reset_config.token_length,
        reason: CommandTower::Secrets::PASSWORD_RESET,
        use_count_max: 1,
        death_time: password_reset_config.token_valid_for,
        type: CommandTower::Secrets::ALPHANUMERIC,
        cleanse: true,
      )
      # Always return success message (security: prevent user enumeration)
      context.message = "If an account exists with that email, a password reset link has been sent."

      if result.failure?
        log_error("Failed to generate password reset token for user [#{user.id}]: #{result.msg}")
        # Still return success to prevent user enumeration
        return
      end

      log_info("Password reset token generated successfully for user [#{user.id}]")

      # Send email with token
      begin
        template_name = password_reset_config.custom_template_name
        CommandTower::PasswordResetMailer.reset_password(user.email, user, result.secret, template_name: template_name).deliver
        log_info("Password reset email sent successfully to user [#{user.id}]")
      rescue StandardError => e
        log_error("Failed to send password reset email to user [#{user.id}]: #{e.message}")
        # CRITICAL: Still return success to prevent user enumeration
        # Never return 500 as it would reveal email exists in system
      end
    end

    private

    def password_reset_config
      CommandTower.config.login.plain_text.password_reset
    end
  end
end

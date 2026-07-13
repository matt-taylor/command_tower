# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::PasswordReset
  class Validate < CommandTower::ServiceBase
    include Helper

    on_argument_validation :fail_early

    validate :token, is_a: String, required: true, sensitive: true
    validate :email, is_a: String, required: false

    def call
      validate_email_required!
      return if context.failure?

      verify_result = validate_token!
      return if context.failure?

      user = get_user_from_token!(verify_result)
      return if context.failure?

      validate_email_match!(token_user: user)
      return if context.failure?

      expires_at = get_expires_at_from_token(verify_result)

      log_info("Password reset token validated successfully for user [#{user.id}]")

      context.valid = true
      context.expires_at = expires_at&.to_s
    end
  end
end

# frozen_string_literal: true

module CommandTower::LoginStrategy::PlainText::PasswordReset
  module Helper
    def validate_email_required!
      return unless password_reset_configuration.require_email
      return unless email.nil? || email.to_s.strip.empty?

      context.fail!(msg: "Email is required", status: 400)
    end

    def validate_email_match!(token_user:)
      # If email is provided, always validate it matches (regardless of require_email setting)
      return unless email && !email.to_s.strip.empty?

      normalized_provided_email = email.to_s.downcase.strip
      normalized_user_email = token_user.email.to_s.downcase.strip
      return if normalized_provided_email == normalized_user_email

      log_warn("Email mismatch for user #{token_user.id}: #{token_user.email} != #{email}")
      context.fail!(msg: "Invalid token", status: 401)
    end

    def validate_token!
      verify_result = CommandTower::Secrets::Verify.(
        secret: token,
        reason: CommandTower::Secrets::PASSWORD_RESET,
        access_count: access_count
      )

      return verify_result if verify_result.success?

      log_token_validation_failure(verify_result)
      context.fail!(msg: "Invalid token", status: 401)
      nil
    end

    def get_user_from_token!(verify_result)
      return nil if verify_result.nil? || verify_result.failure?

      verify_result.user
    end

    def get_expires_at_from_token(verify_result)
      return nil if verify_result.nil? || verify_result.failure?

      # Query UserSecret for expires_at (death_time)
      # Note: This is a single indexed lookup, optimized by secret uniqueness
      user_secret = UserSecret.find_by(secret: token, reason: CommandTower::Secrets::PASSWORD_RESET)
      user_secret&.death_time
    end

    def log_token_validation_failure(verify_result)
      return unless verify_result

      record_data = verify_result.record
      if record_data && record_data[:found]
        record = record_data[:record]
        invalid_reasons = record.invalid_reason
        log_warn("Password reset token validation failed for token: #{token[0..10]}... Reasons: #{invalid_reasons.join(', ')}")
      else
        log_warn("Password reset token not found: #{token[0..10]}...")
      end
    end

    def password_reset_configuration
      CommandTower.config.login.plain_text.password_reset
    end

    def access_count
      # Override in services that need different access_count behavior
      false
    end
  end
end

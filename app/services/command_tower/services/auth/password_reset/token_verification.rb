# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordReset
        # Shared token redemption and email-binding checks for the reset services.
        # A reset token is only honoured for the account it was issued to, and an
        # unusable token is always reported as a plain invalid token so callers
        # cannot tell expired from unknown from already-used.
        module TokenVerification
          private

          def password_reset_configuration
            CommandTower.config.login.plain_text.password_reset
          end

          def require_email!
            return unless password_reset_configuration.require_email
            return if email.to_s.strip.present?

            context.fail!(
              application_error: CommandTower::Errors::ValidationError.new(details: { email: "Email is required" })
            )
          end

          def redeem_token!(access_count:)
            result = CommandTower::Secrets::Verify.(
              secret: token,
              reason: CommandTower::Secrets::PASSWORD_RESET,
              access_count: access_count
            )
            return result if result.success?

            log_token_failure(result)
            invalid_token!
          end

          def match_email!(token_user:)
            return if email.to_s.strip.empty?
            return if email.to_s.downcase.strip == token_user.email.to_s.downcase.strip

            log_warn("Password reset email mismatch for user [#{token_user.id}]")
            invalid_token!
          end

          def token_expires_at
            UserSecret.find_by(secret: token, reason: CommandTower::Secrets::PASSWORD_RESET)&.death_time
          end

          def invalid_token!
            context.fail!(application_error: CommandTower::Errors::Auth::PasswordResetInvalidTokenError.new)
          end

          def log_token_failure(result)
            record_data = result.record
            if record_data && record_data[:found]
              reasons = record_data[:record].invalid_reason.join(", ")
              log_warn("Password reset token rejected. Reasons: #{reasons}")
            else
              log_warn("Password reset token not found")
            end
          end
        end
      end
    end
  end
end

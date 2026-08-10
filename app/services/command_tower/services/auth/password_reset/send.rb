# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PasswordReset
        # Issues a reset token and emails it. Callers always receive the same
        # message so an unknown address cannot be distinguished from a known one.
        class Send < CommandTower::Services::ApplicationService
          SENT_MESSAGE = "If an account exists with that email, a password reset link has been sent."

          validate :email, is_a: String, required: true, sensitive: true

          def call
            malformed_email! unless email =~ URI::MailTo::EMAIL_REGEXP

            user = User.find_by(email: email.downcase.strip)
            context.message = SENT_MESSAGE

            if user.nil?
              log_info("Password reset requested for an email with no account")
              return
            end

            issued = issue_token(user)
            return if issued.nil?

            deliver(user, issued.secret)
          end

          private

          def password_reset_configuration
            CommandTower.config.login.plain_text.password_reset
          end

          def issue_token(user)
            result = CommandTower::Secrets::Generate.(
              user: user,
              secret_length: password_reset_configuration.token_length,
              reason: CommandTower::Secrets::PASSWORD_RESET,
              use_count_max: 1,
              death_time: password_reset_configuration.token_valid_for,
              type: CommandTower::Secrets::ALPHANUMERIC,
              cleanse: true
            )
            return result if result.success?

            # Surfacing the failure would leak that the account exists.
            log_error("Failed to generate a password reset token for user [#{user.id}]: #{result.msg}")
            nil
          end

          def deliver(user, secret)
            CommandTower::PasswordResetMailer.reset_password(
              user.email,
              user,
              secret,
              template_name: password_reset_configuration.custom_template_name
            ).deliver
          rescue StandardError => e
            # Surfacing the failure would leak that the account exists.
            log_error("Failed to send the password reset email to user [#{user.id}]: #{e.message}")
          end

          def malformed_email!
            context.fail!(
              application_error: CommandTower::Errors::ValidationError.new(
                details: { email: "Invalid email address" }
              )
            )
          end
        end
      end
    end
  end
end

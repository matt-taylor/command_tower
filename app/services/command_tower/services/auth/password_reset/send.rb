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

            # Always enqueue exactly one job, known account or not, so neither the
            # response nor the request-side work reveals whether the account exists.
            enqueue(email.downcase.strip)
            context.message = SENT_MESSAGE
          end

          private

          def enqueue(normalized_email)
            if CommandTower.config.login.mail_delivery == :inline
              CommandTower::Auth::PasswordReset::IssueJob.perform_now(normalized_email)
            else
              CommandTower::Auth::PasswordReset::IssueJob.perform_later(normalized_email)
            end
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

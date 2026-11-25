# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module EmailVerification
        # Requests an email-verification code. With login.mail_delivery :later (the
        # default) the code is generated and mailed by IssueJob, which carries only
        # the user id. With :inline the job runs synchronously and a delivery
        # failure still surfaces as VerificationSendFailedError.
        class Send < CommandTower::Services::ApplicationService
          ALREADY_VERIFIED_MESSAGE = "Email is already verified. No code required"
          SENT_MESSAGE = "Successfully sent email verification code"

          validate :user, is_a: User, required: true

          def call
            if user.email_validated
              context.message = ALREADY_VERIFIED_MESSAGE
              return
            end

            enqueue
            context.message = SENT_MESSAGE
          end

          private

          def enqueue
            job_class = CommandTower::Auth::EmailVerification::IssueJob

            if CommandTower.config.login.mail_delivery == :inline
              perform_inline(job_class)
            else
              job_class.perform_later(user.id)
            end
          end

          def perform_inline(job_class)
            job_class.perform_now(user.id)
          rescue StandardError => e
            log_error("Failed to send message to [#{user.id}]: #{e.class}")
            context.fail!(application_error: CommandTower::Errors::Auth::VerificationSendFailedError.new)
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module EmailVerification
        class Send < CommandTower::Services::ApplicationService
          ALREADY_VERIFIED_MESSAGE = "Email is already verified. No code required"
          SENT_MESSAGE = "Successfully sent email verification code"

          validate :user, is_a: User, required: true

          def call
            if user.email_validated
              context.message = ALREADY_VERIFIED_MESSAGE
              return
            end

            secret = issue_code
            deliver(secret)

            context.message = SENT_MESSAGE
          end

          private

          def email_verify
            CommandTower.config.login.plain_text.email_verify
          end

          def issue_code
            result = CommandTower::Secrets::Generate.(
              user:,
              secret_length: email_verify.verify_code_length,
              reason: CommandTower::Secrets::EMAIL_VERIFICIATION,
              use_count_max: 1,
              death_time: email_verify.verify_code_link_valid_for,
              type: CommandTower::Secrets::NUMERIC,
              cleanse: true
            )

            if result.failure?
              log_error("Secret Generation is not available at this time for user [#{user.id}]")
              context.fail!(application_error: CommandTower::Errors::InternalError.new)
            end

            result.secret
          end

          def deliver(secret)
            CommandTower::EmailVerificationMailer.verify_email(
              user.email,
              user,
              secret,
              template_name: email_verify.custom_template_name
            ).deliver
          rescue StandardError => e
            log_error("Failed to send message to [#{user.id}]: #{e.message}")
            context.fail!(application_error: CommandTower::Errors::Auth::VerificationSendFailedError.new)
          end
        end
      end
    end
  end
end

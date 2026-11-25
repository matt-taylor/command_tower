# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module EmailVerification
        # Job-entry orchestration: generate a single-use verification code for the
        # user and email it. Failures raise so the job (or an inline caller) sees
        # them; the code itself is never logged.
        class IssueWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          class DeliveryError < StandardError; end

          def call(user_id:)
            user = User.find_by(id: user_id)
            return success(payload: {}, http_status: :ok) if user.nil? || user.email_validated

            deliver(user, issued_code(user))
            success(payload: {}, http_status: :ok)
          end

          private

          def email_verify
            CommandTower.config.login.plain_text.email_verify
          end

          def issued_code(user)
            result = generate_secret(user)
            return result.secret if result.success?

            log_error("Secret Generation is not available at this time for user [#{user.id}]")
            raise DeliveryError, "verification code generation failed"
          end

          def generate_secret(user)
            CommandTower::Secrets::Generate.call(
              user: user,
              secret_length: email_verify.verify_code_length,
              reason: CommandTower::Secrets::EMAIL_VERIFICIATION,
              use_count_max: 1,
              death_time: email_verify.verify_code_link_valid_for,
              type: CommandTower::Secrets::NUMERIC,
              cleanse: true
            )
          end

          def deliver(user, secret)
            CommandTower::EmailVerificationMailer.verify_email(
              user.email,
              user,
              secret,
              template_name: email_verify.custom_template_name
            ).deliver
          rescue StandardError => e
            log_error("Failed to send verification email to user [#{user.id}]: #{e.class}")
            raise DeliveryError, "verification email delivery failed"
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PasswordReset
        # Job-entry orchestration: look up the account, issue a single-use reset
        # token and email it. Unknown accounts and delivery problems are logged
        # and swallowed so the outcome never varies for the requester.
        class IssueWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(email:)
            user = User.find_by(email: email)
            deliver(user, issued_secret(user)) if user

            success(payload: {}, http_status: :ok)
          end

          private

          def password_reset_configuration
            CommandTower.config.login.plain_text.password_reset
          end

          def issued_secret(user)
            result = generate_secret(user)
            return result.secret if result.success?

            log_error("Failed to generate a password reset token for user [#{user.id}]: #{result.msg}")
            nil
          end

          def generate_secret(user)
            CommandTower::Secrets::Generate.call(
              user: user,
              secret_length: password_reset_configuration.token_length,
              reason: CommandTower::Secrets::PASSWORD_RESET,
              use_count_max: 1,
              death_time: password_reset_configuration.token_valid_for,
              type: CommandTower::Secrets::ALPHANUMERIC,
              cleanse: true
            )
          end

          def deliver(user, secret)
            return if secret.nil?

            CommandTower::PasswordResetMailer.reset_password(
              user.email,
              user,
              secret,
              template_name: password_reset_configuration.custom_template_name
            ).deliver
          rescue StandardError => e
            log_error("Failed to send the password reset email to user [#{user.id}]: #{e.class}")
          end
        end
      end
    end
  end
end

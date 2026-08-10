# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PasswordReset
        class SendWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(input:, password_recovery_session:)
            unless CommandTower.config.login.plain_text.password_reset.enabled
              error = CommandTower::Errors::Auth::PasswordResetUnavailableError.new
              return failure(errors: [error], http_status: IdentityErrorStatus.http_status_for(error))
            end

            rate_result = CommandTower::Services::Auth::PasswordRecovery::RateLimits::CheckSend.call(
              password_recovery_session: password_recovery_session
            )
            unless rate_result.success?
              return failure(
                errors: rate_result.errors,
                http_status: IdentityErrorStatus.http_status_for(rate_result.errors.first)
              )
            end

            send_result = CommandTower::Services::Auth::PasswordReset::Send.call(email: input.email)
            unless send_result.success?
              return failure(
                errors: send_result.errors,
                http_status: IdentityErrorStatus.http_status_for(send_result.errors.first)
              )
            end

            success(
              payload: CommandTower::Serializers::Auth::PasswordReset::MessageResponseSerializer.serialize(
                message: send_result.data[:message]
              ),
              http_status: :ok
            )
          end
        end
      end
    end
  end
end

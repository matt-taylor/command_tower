# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PasswordReset
        class ResetWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(input:)
            unless CommandTower.config.login.plain_text.password_reset.enabled
              error = CommandTower::Errors::Auth::PasswordResetUnavailableError.new
              return failure(errors: [error], http_status: IdentityErrorStatus.http_status_for(error))
            end

            reset_result = CommandTower::Services::Auth::PasswordReset::Reset.call(
              token: input.token,
              password: input.password,
              password_confirmation: input.password_confirmation,
              email: input.email
            )
            unless reset_result.success?
              return failure(
                errors: reset_result.errors,
                http_status: IdentityErrorStatus.http_status_for(reset_result.errors.first)
              )
            end

            success(
              payload: CommandTower::Serializers::Auth::PasswordReset::MessageResponseSerializer.serialize(
                message: reset_result.data[:message]
              ),
              http_status: :ok
            )
          end
        end
      end
    end
  end
end

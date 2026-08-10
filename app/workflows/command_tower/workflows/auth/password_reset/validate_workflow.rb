# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PasswordReset
        class ValidateWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(input:)
            unless CommandTower.config.login.plain_text.password_reset.enabled
              error = CommandTower::Errors::Auth::PasswordResetUnavailableError.new
              return failure(errors: [error], http_status: IdentityErrorStatus.http_status_for(error))
            end

            validate_result = CommandTower::Services::Auth::PasswordReset::Validate.call(
              token: input.token,
              email: input.email
            )
            unless validate_result.success?
              return failure(
                errors: validate_result.errors,
                http_status: IdentityErrorStatus.http_status_for(validate_result.errors.first)
              )
            end

            data = validate_result.data
            success(
              payload: CommandTower::Serializers::Auth::PasswordReset::ValidateResponseSerializer.serialize(
                valid: data[:valid],
                expires_at: data[:expires_at]
              ),
              http_status: :ok
            )
          end
        end
      end
    end
  end
end

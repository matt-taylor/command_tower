# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PasswordRecoverySession
        class AuthenticateWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(request:)
            token_data = CommandTower::PasswordRecovery::AuthorizationHelper.extract_token(request)

            if token_data[:error]
              return failure(errors: [extraction_error(token_data[:error])], http_status: :unauthorized)
            end

            client_ip = CommandTower::Services::Auth::ClientIpResolver.call(request: request)
            validate_result = CommandTower::Services::Auth::PasswordRecoverySession::Validate.call(
              token: token_data[:token],
              client_ip: client_ip
            )

            unless validate_result.success?
              return failure(
                errors: validate_result.errors,
                http_status: IdentityErrorStatus.http_status_for(validate_result.errors.first)
              )
            end

            success(
              payload: { password_recovery_session: validate_result.data[:password_recovery_session] },
              http_status: :ok
            )
          end

          private

          def extraction_error(reason)
            if reason == :missing
              CommandTower::Errors::Auth::PasswordRecoverySessionMissingError.new
            else
              CommandTower::Errors::Auth::PasswordRecoverySessionInvalidError.new
            end
          end
        end
      end
    end
  end
end

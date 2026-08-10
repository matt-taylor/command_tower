# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module PasswordRecoverySession
        class CreateWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(client_ip:)
            rate_result = CommandTower::Services::Auth::PasswordRecovery::RateLimits::CheckTokenIssue.call(
              client_ip: client_ip
            )
            unless rate_result.success?
              return failure(
                errors: rate_result.errors,
                http_status: IdentityErrorStatus.http_status_for(rate_result.errors.first)
              )
            end

            create_result = CommandTower::Services::Auth::PasswordRecoverySession::Create.call
            unless create_result.success?
              return failure(errors: create_result.errors, http_status: :internal_server_error)
            end

            data = create_result.data
            success(
              payload: CommandTower::Serializers::Auth::PasswordRecoverySessionResponseSerializer.serialize(
                token: data[:token],
                expires_at: data[:expires_at]
              ),
              http_status: :created
            )
          end
        end
      end
    end
  end
end

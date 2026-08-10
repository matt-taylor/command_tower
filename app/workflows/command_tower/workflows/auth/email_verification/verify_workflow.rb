# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module EmailVerification
        class VerifyWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:, input:)
            verify_result = CommandTower::Services::Auth::EmailVerification::Verify.call(
              user: current_user,
              code: input.code
            )

            unless verify_result.success?
              return failure(
                errors: verify_result.errors,
                http_status: IdentityErrorStatus.http_status_for(verify_result.errors.first)
              )
            end

            message = verify_result.data[:message]
            success(
              payload: CommandTower::Serializers::Auth::EmailVerification::MessageResponseSerializer.serialize(
                message: message
              ),
              http_status: message.include?("already verified") ? :ok : :created
            )
          end
        end
      end
    end
  end
end

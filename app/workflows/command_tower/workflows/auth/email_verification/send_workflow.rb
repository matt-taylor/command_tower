# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      module EmailVerification
        class SendWorkflow < CommandTower::Workflows::ApplicationWorkflow
          retry_strategy :none

          def call(current_user:)
            send_result = CommandTower::Services::Auth::EmailVerification::Send.call(user: current_user)

            unless send_result.success?
              return failure(
                errors: send_result.errors,
                http_status: IdentityErrorStatus.http_status_for(send_result.errors.first)
              )
            end

            message = send_result.data[:message]
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

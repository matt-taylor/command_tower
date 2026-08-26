# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      class DeleteAccountWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, password:)
          delete_result = CommandTower::Services::Me::DeleteAccount.call(
            user: current_user,
            password:
          )

          unless delete_result.success?
            error = delete_result.errors.first
            return failure(
              errors: delete_result.errors,
              http_status: CommandTower::Workflows::Me::ErrorStatus.http_status_for(error)
            )
          end

          success(
            payload: CommandTower::Serializers::Me::DeleteAccountResponseSerializer.serialize(
              message: delete_result.data[:message]
            ),
            http_status: :ok,
            response_effects: { clear_token: true }
          )
        end
      end
    end
  end
end

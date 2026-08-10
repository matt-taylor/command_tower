# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      class ChangePasswordWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, current_password:, password:, password_confirmation:)
          change_result = CommandTower::Services::Me::ChangePassword.call(
            user: current_user,
            current_password:,
            password:,
            password_confirmation:
          )

          unless change_result.success?
            error = change_result.errors.first
            return failure(
              errors: change_result.errors,
              http_status: CommandTower::Workflows::Me::ErrorStatus.http_status_for(error)
            )
          end

          success(
            payload: CommandTower::Serializers::Me::ChangePasswordResponseSerializer.serialize,
            http_status: :ok,
            response_effects: { clear_token: true }
          )
        end
      end
    end
  end
end

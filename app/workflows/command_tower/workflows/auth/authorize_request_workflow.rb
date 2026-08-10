# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class AuthorizeRequestWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, controller_class:, action_name:)
          authorize_result = CommandTower::Services::Auth::AuthorizeRequest.call(
            current_user: current_user,
            controller_class: controller_class,
            action_name: action_name
          )

          unless authorize_result.success?
            return failure(
              errors: authorize_result.errors,
              http_status: :forbidden
            )
          end

          success(payload: {}, http_status: :ok)
        end
      end
    end
  end
end

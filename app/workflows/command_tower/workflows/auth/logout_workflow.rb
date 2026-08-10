# frozen_string_literal: true

module CommandTower
  module Workflows
    module Auth
      class LogoutWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(input: nil, request_context: nil)
          success(
            payload: CommandTower::Serializers::Auth::LogoutResponseSerializer.serialize,
            http_status: :ok,
            response_effects: { clear_token: true }
          )
        end
      end
    end
  end
end

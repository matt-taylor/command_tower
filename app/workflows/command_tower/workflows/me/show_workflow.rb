# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, auth_context: nil)
          capabilities = CommandTower::Services::Me::Capabilities.project(current_user)
          payload = CommandTower::Serializers::Me::AccountSerializer.serialize(
            current_user,
            capabilities: capabilities
          )

          success(
            payload: payload,
            http_status: :ok,
            response_effects: expire_header_effects(auth_context)
          )
        end

        private

        def expire_header_effects(auth_context)
          return if auth_context.nil?

          { set_expire_header: auth_context.token_expires_at }
        end
      end
    end
  end
end

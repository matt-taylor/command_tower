# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      class UpdateNameWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, first_name:, last_name:, auth_context: nil)
          update_result = CommandTower::Services::Me::UpdateName.call(
            user: current_user,
            first_name:,
            last_name:
          )

          unless update_result.success?
            error = update_result.errors.first
            return failure(
              errors: update_result.errors,
              http_status: CommandTower::Workflows::Me::ErrorStatus.http_status_for(error)
            )
          end

          user = update_result.data[:user].reload
          capabilities = CommandTower::Services::Me::Capabilities.project(user)
          payload = CommandTower::Serializers::Me::AccountSerializer.serialize(
            user,
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

# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      class ClearPhoneWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, auth_context: nil)
          unless CommandTower::Services::Me::SmsProductGate.enabled?
            error = CommandTower::Errors::Account::SmsCapabilityUnavailableError.new
            return failure(
              errors: [error],
              http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error)
            )
          end

          clear_result = CommandTower::Services::Account::ClearPhone.call(user: current_user)

          unless clear_result.success?
            error = clear_result.errors.first
            return failure(
              errors: clear_result.errors,
              http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error)
            )
          end

          user = clear_result.data[:user].reload
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

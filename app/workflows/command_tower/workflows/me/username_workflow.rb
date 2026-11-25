# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      # Self-service username set/change (PATCH /me/username).
      class UsernameWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, username:, auth_context: nil)
          if CommandTower::Current.impersonation_active == true
            return failure(errors: [CommandTower::Errors::ForbiddenError.new], http_status: :forbidden)
          end

          set_result = CommandTower::Services::Me::SetUsername.call(user: current_user, username:)
          return failure_from(set_result) unless set_result.success?

          success(
            payload: account_payload(set_result.data[:user]),
            http_status: :ok,
            response_effects: expire_header_effects(auth_context)
          )
        end

        private

        def failure_from(set_result)
          failure(
            errors: set_result.errors,
            http_status: CommandTower::Workflows::Me::ErrorStatus.http_status_for(set_result.errors.first)
          )
        end

        def account_payload(user)
          capabilities = CommandTower::Services::Me::Capabilities.project(user)
          CommandTower::Serializers::Me::AccountSerializer.serialize(user, capabilities: capabilities)
        end

        def expire_header_effects(auth_context)
          return if auth_context.nil?

          { set_expire_header: auth_context.token_expires_at }
        end
      end
    end
  end
end

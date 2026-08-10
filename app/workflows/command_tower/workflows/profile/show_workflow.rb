# frozen_string_literal: true

module CommandTower
  module Workflows
    module Profile
      class ShowWorkflow < CommandTower::Workflows::ApplicationWorkflow
        retry_strategy :none

        def call(current_user:, auth_context: nil)
          success(
            payload: CommandTower::Serializers::Profile::ProfileSerializer.serialize(current_user),
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

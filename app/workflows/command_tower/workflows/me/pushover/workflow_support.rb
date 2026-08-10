# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module Pushover
        module WorkflowSupport
          module_function

          def capability_failure
            error = CommandTower::Errors::Account::PushoverCapabilityUnavailableError.new
            {
              errors: [error],
              http_status: CommandTower::Workflows::Me::ErrorMapping.http_status_for(error)
            }
          end

          def expire_header_effects(auth_context)
            return if auth_context.nil?

            { set_expire_header: auth_context.token_expires_at }
          end

          def serialize_view(safe_view)
            CommandTower::Serializers::Me::PushoverSerializer.serialize(safe_view)
          end
        end
      end
    end
  end
end

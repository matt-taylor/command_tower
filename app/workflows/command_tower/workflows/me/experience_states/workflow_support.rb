# frozen_string_literal: true

module CommandTower
  module Workflows
    module Me
      module ExperienceStates
        module WorkflowSupport
          module_function

          def expire_header_effects(auth_context)
            return if auth_context.nil?

            { set_expire_header: auth_context.token_expires_at }
          end

          def serialize_view(state)
            CommandTower::Serializers::Me::ExperienceStates::ExperienceStateSerializer.serialize(state)
          end

          def serialize_collection(states)
            CommandTower::Serializers::Me::ExperienceStates::ExperienceStateSerializer.serialize_collection(states)
          end
        end
      end
    end
  end
end

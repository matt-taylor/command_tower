# frozen_string_literal: true

module CommandTower
  module Serializers
    module Me
      module ExperienceStates
        class ExperienceStateSerializer
          def self.serialize(state)
            new(state).serialize
          end

          def self.serialize_collection(states)
            {
              experienceStates: Array(states).map { |state| serialize(state) },
            }
          end

          def initialize(state)
            @state = state
          end

          def serialize
            {
              hostKey: @state.host_key,
              experienceKey: @state.experience_key,
              scopeType: @state.scope_type,
              scopeIdentifier: @state.scope_identifier,
              version: @state.version,
              completedAt: @state.completed_at&.iso8601,
            }
          end
        end
      end
    end
  end
end

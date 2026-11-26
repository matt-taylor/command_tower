# frozen_string_literal: true

module CommandTower
  module Configuration
    module Registry
      module ExperienceStates
        # One registered experience key and the scope types it may be completed under.
        KeyDefinition = Struct.new(:key, :scope_types, :owner, keyword_init: true) do
          def scope_type?(scope_type)
            scope_types.include?(scope_type.to_s)
          end
        end
      end
    end
  end
end

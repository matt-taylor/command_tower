# frozen_string_literal: true

require "class_composer"

module CommandTower
  module Configuration
    module Registry
      module PrincipalCapabilities
        class CapabilityDefinition
          include ClassComposer::Generator

          add_composer :required_entity,
            desc: "RBAC entity name required for this principal capability to appear in the projection " \
                  "(defaults to the capability id when omitted)",
            allowed: [String, Symbol],
            default: ""

          attr_accessor :owner, :id

          def validate_definition!(name:)
            self.id = name.to_s
            self.owner = owner&.to_sym || :host
            entity = required_entity.to_s.strip
            entity = name.to_s if entity.empty?
            self.required_entity = require_segment!(entity, field: "required_entity", name:)
          end

          private

          def require_segment!(value, field:, name:)
            token = value.to_s.strip
            unless token.match?(CommandTower::Events::SEGMENT)
              raise CommandTower::PrincipalCapabilities::InvalidCapabilityDefinitionError,
                "principal capability #{name} has invalid #{field} #{value.inspect}"
            end

            token
          end
        end
      end
    end
  end
end

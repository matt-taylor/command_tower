# frozen_string_literal: true

require "command_tower/principal_capabilities"
require "command_tower/configuration/registry/principal_capabilities/capability_definition"

module CommandTower
  module Configuration
    module Registry
      module PrincipalCapabilities
        class Config
          # Curated CT-owned frontend-projectable capabilities (1:1 entity names).
          # Deliberate registration only — never an automatic Entity.entities dump.
          PLATFORM_CAPABILITIES = %i[
            admin_workspace
            admin_audit_events
            admin_messaging_announcements
            admin_users
            admin_users_update
            admin_rbac_assignments
            admin_impersonation
            me_audit_events
          ].freeze

          def initialize
            @definitions = {}
            @finalized = false
            seed_platform_capabilities!
          end

          def capability(name, owner: :host)
            raise CommandTower::PrincipalCapabilities::FrozenRegistryError,
              "principal capabilities registry is frozen" if @finalized

            normalized = normalize_name!(name)
            existing = @definitions[normalized]
            if existing
              if existing.owner == :command_tower && owner == :host
                raise CommandTower::PrincipalCapabilities::HostOverrideError,
                  "host cannot redefine CommandTower-owned principal capability #{normalized}"
              end

              raise CommandTower::PrincipalCapabilities::DuplicateCapabilityError,
                "principal capability #{normalized} is already registered"
            end

            definition = CapabilityDefinition.new
            yield definition if block_given?
            definition.owner = owner
            definition.validate_definition!(name: normalized)
            @definitions[normalized] = definition
            definition
          end

          def fetch(name)
            normalized = normalize_name!(name)
            definition = @definitions[normalized]
            if definition.nil?
              raise CommandTower::PrincipalCapabilities::UnregisteredCapabilityError,
                "principal capability #{normalized} is not registered"
            end

            definition
          end

          def registered?(name)
            @definitions.key?(normalize_name!(name))
          rescue CommandTower::PrincipalCapabilities::InvalidCapabilityNameError
            false
          end

          def definitions
            @definitions.dup.freeze
          end

          def finalize!
            @definitions.each_value do |definition|
              next unless definition.respond_to?(:class_composer_freeze_objects!)

              definition.class_composer_freeze_objects!(behavior: :raise, children: true)
            end
            @definitions.freeze
            @finalized = true
            self
          end

          def finalized?
            @finalized
          end

          def validate_required_entities!(entities)
            missing = @definitions.filter_map do |name, definition|
              next if entities.key?(definition.required_entity)

              "#{name} requires #{definition.required_entity}"
            end
            return self if missing.empty?

            raise CommandTower::PrincipalCapabilities::MissingRequiredEntityError,
              "principal capabilities reference unknown RBAC entities: #{missing.join(", ")}"
          end

          def reset_host_definitions!
            thaw_for_test!
            @definitions.delete_if { |_name, definition| definition.owner == :host }
            self
          end

          private

          def seed_platform_capabilities!
            PLATFORM_CAPABILITIES.each do |name|
              capability(name, owner: :command_tower)
            end
          end

          def thaw_for_test!
            return unless @finalized || @definitions.frozen?

            @definitions = @definitions.dup
            @finalized = false
          end

          def normalize_name!(name)
            token = name.to_s.strip
            unless token.match?(CommandTower::Events::SEGMENT)
              raise CommandTower::PrincipalCapabilities::InvalidCapabilityNameError,
                "invalid principal capability name #{name.inspect}"
            end

            token
          end
        end
      end
    end
  end
end

# frozen_string_literal: true

require "command_tower/admin_workspace"
require "command_tower/configuration/registry/admin_workspace/tool_definition"

module CommandTower
  module Configuration
    module Registry
      module AdminWorkspace
        class Config
          PLATFORM_TOOLS = {
            users: {
              label: "Users",
              description: "Find and inspect platform user accounts.",
              route: "/admin/users",
              group: "operations",
              sort_order: 50,
              required_entity: "admin_users",
              icon: "users"
            },
            audit: {
              label: "Audit",
              description: "Browse account and administrative audit history.",
              route: "/admin/audit",
              group: "operations",
              sort_order: 100,
              required_entity: "admin_audit_events",
              icon: "history"
            },
            messaging: {
              label: "Messaging",
              description: "Manage platform announcements and administrative messaging.",
              route: "/admin/messaging",
              group: "messaging",
              sort_order: 200,
              required_entity: "admin_messaging_announcements",
              icon: "megaphone"
            }
          }.freeze

          def initialize
            @definitions = {}
            @finalized = false
            seed_platform_tools!
          end

          def tool(name, owner: :host)
            raise CommandTower::AdminWorkspace::FrozenRegistryError, "admin workspace registry is frozen" if @finalized

            normalized = normalize_name!(name)
            existing = @definitions[normalized]
            if existing
              if existing.owner == :command_tower && owner == :host
                raise CommandTower::AdminWorkspace::HostOverrideError,
                  "host cannot redefine CommandTower-owned admin workspace tool #{normalized}"
              end

              raise CommandTower::AdminWorkspace::DuplicateToolError,
                "admin workspace tool #{normalized} is already registered"
            end

            definition = ToolDefinition.new
            yield definition if block_given?
            definition.owner = owner
            definition.validate_definition!(name: normalized)
            assert_unique_route!(definition)
            @definitions[normalized] = definition
            definition
          end

          def configure_tool(name)
            raise CommandTower::AdminWorkspace::FrozenRegistryError, "admin workspace registry is frozen" if @finalized

            normalized = normalize_name!(name)
            definition = fetch(normalized)
            if definition.owner != :command_tower
              raise CommandTower::AdminWorkspace::HostOverrideError,
                "configure_tool is only for CommandTower-owned admin workspace tools"
            end

            yield definition
            definition.validate_definition!(name: normalized)
            definition
          end

          def fetch(name)
            normalized = normalize_name!(name)
            definition = @definitions[normalized]
            if definition.nil?
              raise CommandTower::AdminWorkspace::UnregisteredToolError,
                "admin workspace tool #{normalized} is not registered"
            end

            definition
          end

          def registered?(name)
            @definitions.key?(normalize_name!(name))
          rescue CommandTower::AdminWorkspace::InvalidToolNameError
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

            raise CommandTower::AdminWorkspace::MissingRequiredEntityError,
              "admin workspace tools reference unknown RBAC entities: #{missing.join(", ")}"
          end

          def reset_host_definitions!
            thaw_for_test!
            @definitions.delete_if { |_name, definition| definition.owner == :host }
            self
          end

          private

          def seed_platform_tools!
            PLATFORM_TOOLS.each do |name, attrs|
              tool(name, owner: :command_tower) do |definition|
                definition.label = attrs[:label]
                definition.description = attrs[:description]
                definition.route = attrs[:route]
                definition.group = attrs[:group]
                definition.sort_order = attrs[:sort_order]
                definition.required_entity = attrs[:required_entity]
                definition.icon = attrs[:icon]
              end
            end
          end

          def thaw_for_test!
            return unless @finalized || @definitions.frozen?

            @definitions = @definitions.dup
            @finalized = false
          end

          def assert_unique_route!(definition)
            conflict = @definitions.values.find { |other| other.route == definition.route }
            return unless conflict

            raise CommandTower::AdminWorkspace::DuplicateRouteError,
              "admin workspace tool #{definition.id} reuses route #{definition.route} " \
              "(already registered by #{conflict.id})"
          end

          def normalize_name!(name)
            token = name.to_s.strip
            unless token.match?(CommandTower::Events::SEGMENT)
              raise CommandTower::AdminWorkspace::InvalidToolNameError,
                "invalid admin workspace tool name #{name.inspect}"
            end

            token
          end
        end
      end
    end
  end
end

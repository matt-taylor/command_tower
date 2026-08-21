# frozen_string_literal: true

require "command_tower/admin_scope"
require "command_tower/configuration/admin_scope/tool_registration"

module CommandTower
  module Configuration
    module AdminScope
      class Config
        def initialize
          @registrations = {}
          @finalized = false
        end

        def register(tool_id, &block)
          raise CommandTower::AdminScope::FrozenRegistryError, "admin scope registry is frozen" if @finalized

          normalized = normalize_tool_id!(tool_id)
          if @registrations.key?(normalized)
            raise CommandTower::AdminScope::DuplicateRegistrationError,
              "admin scope registration for #{normalized} already exists"
          end

          registration = ToolRegistration.new
          yield registration if block_given?
          registration.validate!(tool_id: normalized)
          @registrations[normalized] = registration
          registration
        end

        def fetch(tool_id)
          normalized = normalize_tool_id!(tool_id)
          registration = @registrations[normalized]
          if registration.nil?
            raise CommandTower::AdminScope::UnregisteredToolError,
              "admin scope registration for #{normalized} is not registered"
          end

          registration
        end

        def registered?(tool_id)
          @registrations.key?(normalize_tool_id!(tool_id))
        rescue CommandTower::AdminWorkspace::InvalidToolNameError
          false
        end

        def registrations
          @registrations.dup.freeze
        end

        def finalize!
          @registrations.freeze
          @finalized = true
          self
        end

        def finalized?
          @finalized
        end

        def validate_scoped_tools!
          CommandTower.config.registry.admin_workspace.definitions.each do |tool_id, definition|
            next unless definition.scope_required?

            unless registered?(tool_id)
              raise CommandTower::AdminScope::MissingRegistrationError,
                "admin workspace tool #{tool_id} requires scope but has no admin_scope registration"
            end

            fetch(tool_id).validate!(tool_id:)
          end
          self
        end

        def reset_registrations!
          thaw_for_test!
          @registrations.clear
          self
        end

        private

        def normalize_tool_id!(tool_id)
          CommandTower.config.registry.admin_workspace.fetch(tool_id)
          token = tool_id.to_s.strip
          unless token.match?(CommandTower::Events::SEGMENT)
            raise CommandTower::AdminWorkspace::InvalidToolNameError,
              "invalid admin scope tool id #{tool_id.inspect}"
          end

          token
        end

        def thaw_for_test!
          return unless @finalized || @registrations.frozen?

          @registrations = @registrations.dup
          @finalized = false
        end
      end
    end
  end
end

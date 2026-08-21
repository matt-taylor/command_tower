# frozen_string_literal: true

require "yaml"
require "set"
require "command_tower/error"
require "command_tower/authorization/entity"
require "command_tower/authorization/role"
require "command_tower/authorization/effective_entity_grants"
require "command_tower/authorization/assignable_roles"

module CommandTower
  module Authorization
    module_function

    class Error < CommandTower::Error; end

    SOURCE_COMMAND_TOWER = :command_tower
    SOURCE_HOST = :host

    def mapped_controllers
      @mapped_controllers ||= {}
    end

    def add_mapping!(role:)
      role.guards.each do |controller, methods|
        mapped_controllers[controller] ||= Set.new
        mapped_controllers[controller] += methods
      end
    end

    def mapped_controllers_reset!
      @mapped_controllers = {}
    end

    def reset_graph!
      CommandTower::Authorization::Role.roles_reset!
      CommandTower::Authorization::Entity.entities_reset!
      mapped_controllers_reset!
    end

    def default_defined!(validate: true)
      reset_graph!
      provision_rbac_default!
      provision_rbac_user_defined!
      validate_composed_graph! if validate
    end

    def provision_rbac_user_defined!
      path = CommandTower.config.authorization.rbac_group_path
      rbac_configuration = load_yaml(path)
      provision_rbac_via_yaml(rbac_configuration, source: SOURCE_HOST)
    end

    def provision_rbac_default!
      path = CommandTower::Engine.root.join("lib", "command_tower", "authorization", "default.yml")
      rbac_configuration = load_yaml(path)
      provision_rbac_via_yaml(rbac_configuration, source: SOURCE_COMMAND_TOWER)
    end

    def load_yaml(path)
      return nil unless File.exist?(path)

      YAML.load_file(path)
    end

    def provision_rbac_via_yaml(rbac_configuration, source:)
      return if rbac_configuration.nil?

      unless rbac_configuration.is_a?(Hash)
        raise Error, "RBAC source must be a mapping (got #{rbac_configuration.class})"
      end

      entity_rows = rbac_configuration["entities"]
      if !entity_rows.nil? && !entity_rows.is_a?(Array)
        raise Error, "RBAC entities must be a list"
      end

      Array(entity_rows).each do |entity|
        raise Error, "RBAC entity definition must be a mapping" unless entity.is_a?(Hash)
        raise Error, "RBAC entity is missing name" if entity["name"].blank?

        CommandTower::Authorization::Entity.create_entity(
          name: entity["name"],
          controller: entity["controller"],
          only: entity["only"],
          except: entity["except"],
          source: source,
        )
      end

      groups = rbac_configuration["groups"]
      return if groups.nil?

      unless groups.is_a?(Hash)
        raise Error, "RBAC groups must be a mapping"
      end

      groups.each do |name, metadata|
        raise Error, "RBAC group [#{name}] must be a mapping" unless metadata.is_a?(Hash)

        description = metadata["description"]
        allow_everything = false
        entities = nil

        if metadata["entities"] == true
          allow_everything = true
        else
          grant_names = Array(metadata["entities"])
          entities = grant_names.map do |grant_name|
            resolved = CommandTower::Authorization::Entity.entities[grant_name]
            if resolved.nil?
              raise Error, "RBAC group [#{name}] references unknown entity [#{grant_name}]"
            end
            resolved
          end
        end

        CommandTower::Authorization::Role.create_role(
          name:,
          entities:,
          description:,
          allow_everything:,
          source: source,
        )
      end
    end

    def validate_composed_graph!
      validate_default_membership_role!
    end

    def validate_default_membership_role!
      role_name = CommandTower.config.authorization.default_membership_role
      return if role_name.nil?

      if role_name.to_s.strip.empty?
        raise Error, "authorization.default_membership_role is blank; use nil to disable default assignment"
      end

      return if CommandTower::Authorization::Role.roles[role_name]

      raise Error,
        "authorization.default_membership_role [#{role_name}] is not present in the composed RBAC graph"
    end
  end
end

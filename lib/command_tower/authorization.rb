# frozen_string_literal: true

require "yaml"
require "set"
require "command_tower/error"
require "command_tower/authorization/entity"
require "command_tower/authorization/role"

module CommandTower
  module Authorization
    module_function

    class Error < CommandTower::Error; end

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

    def default_defined!
      provision_rbac_default!
      provision_rbac_user_defined!
    end

    def provision_rbac_user_defined!
      path = CommandTower.config.authorization.rbac_group_path
      rbac_configuration = load_yaml(path)
      provision_rbac_via_yaml(rbac_configuration)
    end

    def provision_rbac_default!
      path = CommandTower::Engine.root.join("lib", "command_tower", "authorization", "default.yml")
      rbac_configuration = load_yaml(path)
      provision_rbac_via_yaml(rbac_configuration)
    end

    def load_yaml(path)
      return nil unless File.exist?(path)

      YAML.load_file(path)
    end

    def provision_rbac_via_yaml(rbac_configuration)
      return if rbac_configuration.nil?

      rbac_configuration["entities"].each do |entity|
        CommandTower::Authorization::Entity.create_entity(
          name: entity["name"],
          controller: entity["controller"],
          only: entity["only"],
          except: entity["except"],
        )
      end

      rbac_configuration["groups"].each do |name, metadata|
        entities = nil
        allow_everything = false
        description = metadata["description"]

        if metadata["entities"] == true
          allow_everything =  true
        else
          entities = CommandTower::Authorization::Entity.entities.map { |k, v| v if metadata["entities"].include?(k) }.compact
        end

        CommandTower::Authorization::Role.create_role(
          name:,
          entities:,
          description:,
          allow_everything:,
        )
      end
    end
  end
end

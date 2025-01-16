# frozen_string_literal: true

require "yaml"
require "set"
require "api_engine_base/error"
require "api_engine_base/authorization/entity"
require "api_engine_base/authorization/role"

module ApiEngineBase
  module Authorization
    module_function

    class Error < ApiEngineBase::Error; end

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
      path = ApiEngineBase.config.authorization.rbac_group_path
      rbac_configuration = load_yaml(path)
      provision_rbac_via_yaml(rbac_configuration)
    end

    def provision_rbac_default!
      path = ApiEngineBase::Engine.root.join("lib", "api_engine_base", "authorization", "default.yml")
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
        ApiEngineBase::Authorization::Entity.create_entity(
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
          entities = ApiEngineBase::Authorization::Entity.entities.map { |k, v| v if metadata["entities"].include?(k) }.compact
        end

        ApiEngineBase::Authorization::Role.create_role(
          name:,
          entities:,
          description:,
          allow_everything:,
        )
      end
    end
  end
end

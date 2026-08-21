# frozen_string_literal: true

module CommandTower
  module Services
    module Auth
      module PrincipalCapabilities
        # Projects possessed frontend-projectable capability ids for the effective user.
        # Derives from composed RBAC grants ∩ curated principal_capabilities registry.
        class Project < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            context.principal_capability_ids = possessed_capability_ids
          end

          private

          def possessed_capability_ids
            definitions = CommandTower.config.registry.principal_capabilities.definitions.values
            ids =
              if allow_everything?
                definitions.map(&:id)
              else
                definitions.select { |definition| granted?(definition.required_entity) }.map(&:id)
              end
            ids.uniq.sort
          end

          def allow_everything?
            Array(user.roles).any? do |role_name|
              role = CommandTower::Authorization::Role.roles[role_name]
              role&.allow_everything
            end
          end

          def granted?(entity_name)
            Array(user.roles).any? do |role_name|
              role = CommandTower::Authorization::Role.roles[role_name]
              next false unless role

              role.allow_everything || role.entities.any? { |entity| entity.name.to_s == entity_name }
            end
          end
        end
      end
    end
  end
end

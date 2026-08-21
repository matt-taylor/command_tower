# frozen_string_literal: true

module CommandTower
  module Services
    module Admin
      module Workspace
        class Manifest < CommandTower::Services::ApplicationService
          validate :user, is_a: User, required: true

          def call
            context.tools = authorized_definitions.map { |definition| project(definition) }
          end

          private

          def authorized_definitions
            CommandTower.config.registry.admin_workspace.definitions.values.select do |definition|
              granted?(definition.required_entity)
            end.sort_by { |definition| [definition.group, definition.sort_order, definition.id] }
          end

          def granted?(entity_name)
            Array(user.roles).any? do |role_name|
              role = CommandTower::Authorization::Role.roles[role_name]
              next false unless role

              role.allow_everything || role.entities.any? { |entity| entity.name.to_s == entity_name }
            end
          end

          def project(definition)
            base = {
              id: definition.id,
              label: definition.label,
              description: definition.description,
              route: definition.route,
              group: definition.group,
              sort_order: definition.sort_order,
              icon: definition.icon
            }
            base.merge(
              CommandTower::AdminScope::ManifestProjection.call(definition:, principal: user)
            )
          end
        end
      end
    end
  end
end

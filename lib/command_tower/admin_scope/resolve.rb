# frozen_string_literal: true

module CommandTower
  module AdminScope
    module Resolve
      module_function

      def call(tool_id:, principal:, scope_value:)
        definition = CommandTower.config.registry.admin_workspace.fetch(tool_id)
        return nil unless definition.scope_required?

        token = scope_value.to_s.strip
        if token.empty?
          raise CommandTower::Errors::ForbiddenError
        end

        registration = CommandTower.config.admin_scope.fetch(tool_id)
        valid = registration.validate.call(value: token, principal:)
        unless valid
          raise CommandTower::Errors::ForbiddenError
        end

        ScopeContext.new(
          tool_id: definition.id,
          scope_value: token,
          scope_parameter: definition.scope_parameter
        )
      end
    end
  end
end

# frozen_string_literal: true

module CommandTower
  module AdminScope
    module ApplyUsersNarrowing
      module_function

      def call(relation:, scope_context:, principal:)
        return relation if scope_context.nil?

        registration = CommandTower.config.admin_scope.fetch(scope_context.tool_id)
        registration.narrow_users.call(
          relation:,
          scope_value: scope_context.scope_value,
          principal:,
          tool_id: scope_context.tool_id
        )
      end
    end
  end
end

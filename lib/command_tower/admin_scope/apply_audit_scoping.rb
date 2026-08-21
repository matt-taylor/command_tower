# frozen_string_literal: true

module CommandTower
  module AdminScope
    module ApplyAuditScoping
      module_function

      def call(relation:, scope_context:, principal:)
        return relation if scope_context.nil?

        registration = CommandTower.config.admin_scope.fetch(scope_context.tool_id)
        global_event_names = global_visible_event_names
        affected_user_ids = registration.affected_users_in_scope.call(
          scope_value: scope_context.scope_value,
          principal:,
          tool_id: scope_context.tool_id
        )

        host_relation = registration.narrow_audit.call(
          relation: relation.where(scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:host]),
          scope_value: scope_context.scope_value,
          principal:,
          tool_id: scope_context.tool_id
        )

        global_relation = relation.where(
          scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:global],
          action: global_event_names,
          affected_user_id: affected_user_ids
        )

        relation.where(id: host_relation.select(:id))
          .or(relation.where(id: global_relation.select(:id)))
          .where.not(scope_class: CommandTower::Audit::Event::SCOPE_CLASSES[:legacy])
      end

      def global_visible_event_names
        CommandTower.config.registry.audit.definitions.filter_map do |name, definition|
          name if definition.global_visible_in_host_scope?
        end
      end
      private_class_method :global_visible_event_names
    end
  end
end

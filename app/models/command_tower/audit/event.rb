# frozen_string_literal: true

module CommandTower
  module Audit
    class Event < CommandTower::ApplicationRecord
      self.table_name = "command_tower_audit_events"

      ATTRIBUTION_MODES = %w[self_service admin_direct impersonation system].freeze
      SCOPE_CLASSES = {
        global: "global",
        host: "host",
        legacy: "legacy"
      }.freeze

      validates :event_uuid, :action, :occurred_at, :attribution_mode, :scope_class, presence: true
      validates :attribution_mode, inclusion: { in: ATTRIBUTION_MODES }
      validates :scope_class, inclusion: { in: SCOPE_CLASSES.values }
      validates :originating_administrator_id, presence: true, if: :impersonation_active?

      # Force JSON attribute types so writes are JSON.generate'd on every adapter.
      # MySQL 8 already maps t.json → Type::Json (serialize is rejected). MariaDB
      # often stores t.json as LONGTEXT + json_valid CHECK and would otherwise
      # persist Hash#inspect — failing the CHECK (HTTP 500 on login_failed audit).
      attribute :metadata, :json, default: -> { {} }
      attribute :change_set, :json, default: -> { {} }
      attribute :sensitive_fields, :json, default: -> { [] }

      before_update :reject_mutation
      before_destroy :reject_mutation

      private

      def reject_mutation
        raise ImmutableError, "audit events are append-only"
      end
    end
  end
end

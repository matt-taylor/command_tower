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

      after_initialize do
        write_attribute(:change_set, {}) if has_attribute?(:change_set) && read_attribute(:change_set).nil?
        write_attribute(:metadata, {}) if has_attribute?(:metadata) && read_attribute(:metadata).nil?
        write_attribute(:sensitive_fields, []) if has_attribute?(:sensitive_fields) && read_attribute(:sensitive_fields).nil?
      end

      before_update :reject_mutation
      before_destroy :reject_mutation

      private

      def reject_mutation
        raise ImmutableError, "audit events are append-only"
      end
    end
  end
end

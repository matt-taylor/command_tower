# frozen_string_literal: true

class AddScopeColumnsToCommandTowerAuditEvents < ActiveRecord::Migration[7.2]
  def up
    change_table :command_tower_audit_events, bulk: true do |t|
      t.string :scope_class, null: false, default: "legacy"
      t.string :host_context_type
      t.string :host_context_identifier
    end

    execute <<~SQL.squish
      UPDATE command_tower_audit_events
      SET scope_class = 'legacy'
      WHERE scope_class IS NULL OR scope_class = 'legacy'
    SQL

    add_index :command_tower_audit_events,
      %i[host_context_type host_context_identifier occurred_at],
      name: "index_ct_audit_events_on_host_context_occurred"
    add_index :command_tower_audit_events,
      %i[scope_class occurred_at],
      name: "index_ct_audit_events_on_scope_class_occurred"
  end

  def down
    change_table :command_tower_audit_events, bulk: true do |t|
      t.remove_index name: "index_ct_audit_events_on_host_context_occurred"
      t.remove_index name: "index_ct_audit_events_on_scope_class_occurred"
      t.remove :scope_class
      t.remove :host_context_type
      t.remove :host_context_identifier
    end
  end
end

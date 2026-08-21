# frozen_string_literal: true

class CreateCommandTowerAuditEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :command_tower_audit_events, charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci" do |t|
      t.string :event_uuid, null: false
      t.string :action, null: false
      t.datetime :occurred_at, null: false

      t.string :execution_uuid
      t.string :correlation_id
      t.string :request_id
      t.string :causation_id
      t.string :source

      t.bigint :actor_user_id
      t.bigint :affected_user_id
      t.bigint :effective_user_id
      t.bigint :originating_administrator_id
      t.boolean :impersonation_active, null: false, default: false
      t.string :attribution_mode, null: false

      t.string :subject_type
      t.bigint :subject_id
      t.string :subject_label

      t.json :change_set, null: false
      t.json :metadata, null: false

      t.boolean :user_history, null: false
      t.json :sensitive_fields, null: false
      t.string :retention, null: false

      t.timestamps
    end

    add_index :command_tower_audit_events, :event_uuid, unique: true, name: "index_ct_audit_events_on_event_uuid"
    add_index :command_tower_audit_events, %i[affected_user_id occurred_at], name: "index_ct_audit_events_on_affected_occurred"
    add_index :command_tower_audit_events, %i[actor_user_id occurred_at], name: "index_ct_audit_events_on_actor_occurred"
    add_index :command_tower_audit_events, %i[action occurred_at], name: "index_ct_audit_events_on_action_occurred"
    add_index :command_tower_audit_events, :execution_uuid, name: "index_ct_audit_events_on_execution_uuid"
    add_index :command_tower_audit_events, :correlation_id, name: "index_ct_audit_events_on_correlation_id"
    add_index :command_tower_audit_events, %i[originating_administrator_id occurred_at], name: "index_ct_audit_events_on_originating_admin_occurred"
  end
end

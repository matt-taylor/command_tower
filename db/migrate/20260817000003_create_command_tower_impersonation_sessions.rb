# frozen_string_literal: true

class CreateCommandTowerImpersonationSessions < ActiveRecord::Migration[7.2]
  def change
    create_table :command_tower_impersonation_sessions, id: { type: :string, limit: 36 } do |t|
      t.bigint :actor_user_id, null: false
      t.bigint :target_user_id, null: false
      t.datetime :started_at, null: false
      t.datetime :last_activity_at, null: false
      t.datetime :absolute_expires_at, null: false
      t.datetime :idle_expires_at, null: false
        t.datetime :ended_at
        t.string :end_reason, limit: 32
        t.timestamps
      end

      add_index :command_tower_impersonation_sessions, :actor_user_id
      add_index :command_tower_impersonation_sessions, :target_user_id
      add_index :command_tower_impersonation_sessions,
        %i[actor_user_id ended_at],
        name: "index_ct_impersonation_sessions_on_actor_ended"

      add_foreign_key :command_tower_impersonation_sessions, :users, column: :actor_user_id
      add_foreign_key :command_tower_impersonation_sessions, :users, column: :target_user_id
    end
end

# frozen_string_literal: true

class CreateCommandTowerDeviceSessions < ActiveRecord::Migration[7.2]
  TABLE = :command_tower_device_sessions
  LEGACY_INDEX = "index_ct_device_sessions_on_user_legacy_generated_at"

  def change
    create_table TABLE do |t|
      add_identity_columns(t)
      add_lifecycle_columns(t)
      t.timestamps
    end
    add_device_sessions_indexes
    add_foreign_key TABLE, :users
  end

  private

  def add_identity_columns(table)
    table.string :public_id, limit: 36, null: false
    table.bigint :user_id, null: false
    table.string :installation_id, limit: 36
    table.string :platform, limit: 16
    table.string :app_version, limit: 32
  end

  def add_lifecycle_columns(table)
    table.datetime :last_seen_at, null: false
    table.datetime :absolute_expires_at, null: false
    table.datetime :revoked_at
    table.string :revoked_reason, limit: 32
    table.datetime :legacy_generated_at
  end

  def add_device_sessions_indexes
    add_index TABLE, :public_id, unique: true
    add_index TABLE, %i[user_id revoked_at]
    add_index TABLE, :installation_id
    add_index TABLE, %i[user_id legacy_generated_at], unique: true, name: LEGACY_INDEX
    add_index TABLE, :revoked_at
    add_index TABLE, :absolute_expires_at
  end
end

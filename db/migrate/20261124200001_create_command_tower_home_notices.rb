# frozen_string_literal: true

class CreateCommandTowerHomeNotices < ActiveRecord::Migration[7.2]
  def change
    create_table :command_tower_home_notices do |t|
      t.string :public_id, null: false, limit: 32
      t.references :user, null: false, foreign_key: true
      t.string :kind, null: false, limit: 16
      t.string :key, null: false, limit: 128
      t.string :campaign_key, limit: 128
      t.string :period_key, null: false, default: "", limit: 191
      t.string :identity, limit: 191
      t.bigint :communication_id
      t.datetime :starts_at
      t.datetime :ends_at
      t.json :metadata
      t.integer :impression_count, null: false, default: 0
      t.datetime :first_shown_at
      t.datetime :last_shown_at
      t.datetime :acknowledged_at
      t.string :acknowledged_content_hash, limit: 64
      t.datetime :dismissed_until
      t.timestamps
    end

    add_index :command_tower_home_notices, :public_id, unique: true
    add_index :command_tower_home_notices,
              %i[user_id campaign_key period_key],
              unique: true,
              name: "index_ct_home_notices_on_user_campaign_period"
    add_index :command_tower_home_notices,
              %i[user_id identity],
              unique: true,
              name: "index_ct_home_notices_on_user_identity"
    add_index :command_tower_home_notices,
              %i[user_id kind acknowledged_at],
              name: "index_ct_home_notices_on_user_kind_acknowledged"
    add_index :command_tower_home_notices,
              %i[user_id last_shown_at],
              name: "index_ct_home_notices_on_user_last_shown"
    add_index :command_tower_home_notices, :updated_at
  end
end

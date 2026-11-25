# frozen_string_literal: true

class CreateCommandTowerHomeNoticeControls < ActiveRecord::Migration[7.2]
  def change
    create_table :command_tower_home_notice_controls, id: false do |t|
      t.string :key, null: false, limit: 128, primary_key: true
      t.boolean :enabled, null: false, default: true
      t.bigint :updated_by_user_id
      t.timestamps
    end
  end
end

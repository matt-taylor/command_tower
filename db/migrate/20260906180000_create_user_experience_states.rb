# frozen_string_literal: true

class CreateUserExperienceStates < ActiveRecord::Migration[7.2]
  def change
    create_table :user_experience_states do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true
      t.string :host_key, null: false, limit: 128
      t.string :experience_key, null: false, limit: 128
      t.string :scope_type, null: false, limit: 128
      t.string :scope_identifier, null: false, limit: 128
      t.string :version, null: false, limit: 128
      t.datetime :completed_at, null: false
    end

    add_index :user_experience_states,
              %i[user_id host_key experience_key scope_type scope_identifier version],
              unique: true,
              name: "index_user_experience_states_unique"

    add_index :user_experience_states,
              %i[user_id host_key],
              name: "index_user_experience_states_on_user_host"
  end
end

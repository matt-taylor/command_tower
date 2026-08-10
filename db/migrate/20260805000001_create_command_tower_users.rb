# frozen_string_literal: true

class CreateCommandTowerUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :users do |t|
      t.string :first_name, null: false, default: ""
      t.string :last_name, null: false, default: ""
      t.string :username

      t.string :last_known_timezone
      t.timestamp :last_known_timezone_update

      t.integer :successful_login, default: 0
      t.string :last_login_strategy
      t.datetime :last_login

      t.string :roles, default: ""

      # Database token to verify JWT — allows JWT values to expire/reset all devices
      t.string :verifier_token
      t.datetime :verifier_token_last_reset

      # Login Strategy: PlainText
      t.string :email, null: false, default: ""
      t.boolean :email_validated, default: false
      t.integer :password_consecutive_fail, default: 0
      t.string :password_digest, null: false, default: ""
      t.string :recovery_password_digest, null: false, default: ""

      # Identity phone
      t.string :phone_number
      t.boolean :phone_number_validated, null: false, default: false

      t.timestamps
    end

    add_index :users, :username, unique: true
    add_index :users, :phone_number, unique: true
  end
end

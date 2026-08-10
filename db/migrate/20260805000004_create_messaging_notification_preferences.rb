# frozen_string_literal: true

class CreateMessagingNotificationPreferences < ActiveRecord::Migration[7.2]
  def change
    create_table :messaging_notification_preferences do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true
      t.string :notification_type_key, null: false
      t.text :state, null: false
    end

    add_index :messaging_notification_preferences,
              %i[user_id notification_type_key],
              unique: true,
              name: "index_messaging_notification_preferences_unique"
  end
end

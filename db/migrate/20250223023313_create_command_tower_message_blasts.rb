class CreateCommandTowerMessageBlasts < ActiveRecord::Migration[7.2]
  def change
    create_table :message_blasts do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true # Required
      t.text :text
      t.string :title
      t.boolean :existing_users, default: false
      t.boolean :new_users, default: false
    end

    add_reference :messages, :message_blast, foreign_key: true, null: true
  end
end

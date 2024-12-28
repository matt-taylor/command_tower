class CreateApiEngineBaseUserSecrets < ActiveRecord::Migration[7.2]
  def change
    create_table :user_secrets do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :use_count, default: 0
      t.integer :use_count_max
      t.string :reason
      t.string :extra
      t.string :secret
      t.datetime :death_time

      t.timestamps
    end
    add_index :user_secrets, :secret, unique: true
  end
end

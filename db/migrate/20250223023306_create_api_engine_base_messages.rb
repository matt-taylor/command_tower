class CreateApiEngineBaseMessages < ActiveRecord::Migration[7.2]
  def change
    create_table :messages do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true # Required
      t.text :text
      t.string :title
      t.boolean :viewed, default: false
      t.boolean :pushed, default: false
    end
  end
end

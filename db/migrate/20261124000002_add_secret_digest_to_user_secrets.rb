# frozen_string_literal: true

class AddSecretDigestToUserSecrets < ActiveRecord::Migration[7.2]
  def change
    add_column :user_secrets, :secret_digest, :string, limit: 64
    add_index :user_secrets, :secret_digest, unique: true
  end
end

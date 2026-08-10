# frozen_string_literal: true

class CreateMessagingEndpointsAndPushoverCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :messaging_endpoints do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true
      t.string :channel_key, null: false
      t.string :lifecycle_state, null: false
      t.string :verification_state, null: false
      t.string :address_fingerprint, null: false
      t.string :masked_display_value, null: false
      t.text :address_ciphertext # nullable for typed credential channels (e.g. Pushover)
      t.integer :encryption_key_version, null: false, default: 1
      t.integer :lock_version, null: false, default: 0
      t.datetime :verified_at
      t.datetime :revoked_at
      t.datetime :last_successful_use_at
      t.string :active_fingerprint
      t.string :single_active_slot
    end

    add_index :messaging_endpoints,
              %i[user_id channel_key active_fingerprint],
              unique: true,
              name: "index_messaging_endpoints_active_fingerprint"
    add_index :messaging_endpoints,
              %i[single_active_slot],
              unique: true,
              name: "index_messaging_endpoints_single_active_slot"
    add_index :messaging_endpoints,
              %i[user_id channel_key],
              name: "index_messaging_endpoints_owner_channel"

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          ALTER TABLE messaging_endpoints
          ADD CONSTRAINT chk_messaging_endpoints_lifecycle
          CHECK (lifecycle_state IN ('active', 'revoked', 'invalid', 'retired'))
        SQL
        execute <<~SQL.squish
          ALTER TABLE messaging_endpoints
          ADD CONSTRAINT chk_messaging_endpoints_verification
          CHECK (verification_state IN ('unverified', 'pending', 'verified', 'failed'))
        SQL
      end
      dir.down do
        execute "ALTER TABLE messaging_endpoints DROP CHECK chk_messaging_endpoints_lifecycle"
        execute "ALTER TABLE messaging_endpoints DROP CHECK chk_messaging_endpoints_verification"
      end
    end

    create_table :messaging_endpoint_pushover_credentials do |t|
      t.timestamps
      t.bigint :messaging_endpoint_id, null: false
      t.text :user_key_ciphertext, null: false
      t.text :application_token_ciphertext, null: false
      t.integer :encryption_key_version, null: false, default: 1
    end

    add_index :messaging_endpoint_pushover_credentials,
              :messaging_endpoint_id,
              unique: true,
              name: "index_messaging_pushover_credentials_on_endpoint_id"

    add_foreign_key :messaging_endpoint_pushover_credentials,
                    :messaging_endpoints,
                    column: :messaging_endpoint_id,
                    on_delete: :cascade
  end
end

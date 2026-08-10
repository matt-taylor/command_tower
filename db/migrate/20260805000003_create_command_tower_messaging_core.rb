# frozen_string_literal: true

class CreateCommandTowerMessagingCore < ActiveRecord::Migration[7.2]
  def change
    create_table :messaging_communications do |t|
      t.timestamps
      t.references :user, null: false, foreign_key: true
      t.string :notification_type_key, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.text :metadata
      t.string :host_event_identity
      t.string :accept_request_fingerprint
      t.string :status
      t.string :execution_handoff_status, null: false
    end

    add_index :messaging_communications,
              %i[user_id notification_type_key host_event_identity],
              unique: true,
              name: "index_messaging_communications_on_idempotency_namespace"
    add_index :messaging_communications,
              %i[status execution_handoff_status updated_at],
              name: "index_messaging_communications_on_handoff_recovery"

    create_table :messaging_destination_plans do |t|
      t.timestamps
      t.references :communication,
                   null: false,
                   foreign_key: { to_table: :messaging_communications, on_delete: :cascade },
                   index: { unique: true }
      t.text :decision
    end

    create_table :messaging_inbox_items do |t|
      t.timestamps
      t.references :communication,
                   null: false,
                   foreign_key: { to_table: :messaging_communications, on_delete: :cascade },
                   index: { unique: true }
      t.string :status
      t.datetime :viewed_at
      t.datetime :archived_at
      t.datetime :deleted_at
    end

    add_index :messaging_inbox_items,
              %i[deleted_at archived_at viewed_at],
              name: "index_messaging_inbox_items_on_lifecycle"

    create_table :messaging_channel_deliveries do |t|
      t.timestamps
      t.references :communication,
                   null: false,
                   foreign_key: { to_table: :messaging_communications, on_delete: :cascade },
                   index: true
      t.string :channel_key, null: false
      t.string :status
      t.datetime :execution_claimed_at
      t.integer :execution_attempt_count, null: false, default: 0
    end

    add_index :messaging_channel_deliveries,
              %i[communication_id channel_key],
              unique: true,
              name: "index_messaging_channel_deliveries_on_comm_and_channel"
    add_index :messaging_channel_deliveries,
              %i[status execution_claimed_at updated_at],
              name: "index_messaging_channel_deliveries_on_execution_recovery"

    create_table :messaging_delivery_attempts do |t|
      t.timestamps
      t.references :channel_delivery,
                   null: false,
                   foreign_key: { to_table: :messaging_channel_deliveries, on_delete: :cascade },
                   index: true
      t.string :status, null: false
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.string :error_class
      t.string :error_code
      t.string :provider_message_id
      t.string :normalized_provider_status
    end

    add_index :messaging_delivery_attempts,
              %i[channel_delivery_id status],
              name: "index_messaging_delivery_attempts_on_delivery_and_status"
  end
end

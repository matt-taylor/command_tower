# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_26_140000) do
  create_table "command_tower_audit_events", charset: "utf8mb3", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "actor_user_id"
    t.bigint "affected_user_id"
    t.string "attribution_mode", null: false
    t.string "causation_id"
    t.json "change_set", null: false
    t.string "correlation_id"
    t.datetime "created_at", null: false
    t.bigint "effective_user_id"
    t.string "event_uuid", null: false
    t.string "execution_uuid"
    t.string "host_context_identifier"
    t.string "host_context_type"
    t.boolean "impersonation_active", default: false, null: false
    t.json "metadata", null: false
    t.datetime "occurred_at", null: false
    t.bigint "originating_administrator_id"
    t.string "request_id"
    t.string "retention", null: false
    t.string "scope_class", default: "legacy", null: false
    t.json "sensitive_fields", null: false
    t.string "source"
    t.bigint "subject_id"
    t.string "subject_label"
    t.string "subject_type"
    t.datetime "updated_at", null: false
    t.boolean "user_history", null: false
    t.index ["action", "occurred_at"], name: "index_ct_audit_events_on_action_occurred"
    t.index ["actor_user_id", "occurred_at"], name: "index_ct_audit_events_on_actor_occurred"
    t.index ["affected_user_id", "occurred_at"], name: "index_ct_audit_events_on_affected_occurred"
    t.index ["correlation_id"], name: "index_ct_audit_events_on_correlation_id"
    t.index ["event_uuid"], name: "index_ct_audit_events_on_event_uuid", unique: true
    t.index ["execution_uuid"], name: "index_ct_audit_events_on_execution_uuid"
    t.index ["host_context_type", "host_context_identifier", "occurred_at"], name: "index_ct_audit_events_on_host_context_occurred"
    t.index ["originating_administrator_id", "occurred_at"], name: "index_ct_audit_events_on_originating_admin_occurred"
    t.index ["scope_class", "occurred_at"], name: "index_ct_audit_events_on_scope_class_occurred"
  end

  create_table "command_tower_impersonation_sessions", id: { type: :string, limit: 36 }, charset: "utf8mb3", force: :cascade do |t|
    t.datetime "absolute_expires_at", null: false
    t.bigint "actor_user_id", null: false
    t.datetime "created_at", null: false
    t.string "end_reason", limit: 32
    t.datetime "ended_at"
    t.datetime "idle_expires_at", null: false
    t.datetime "last_activity_at", null: false
    t.datetime "started_at", null: false
    t.bigint "target_user_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_user_id", "ended_at"], name: "index_ct_impersonation_sessions_on_actor_ended"
    t.index ["actor_user_id"], name: "index_command_tower_impersonation_sessions_on_actor_user_id"
    t.index ["target_user_id"], name: "index_command_tower_impersonation_sessions_on_target_user_id"
  end

  create_table "foundation_proof_partitions", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "label", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_foundation_proof_partitions_on_slug", unique: true
  end

  create_table "foundation_proof_user_partitions", charset: "utf8mb3", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "foundation_proof_partition_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["foundation_proof_partition_id"], name: "idx_on_foundation_proof_partition_id_7e193d5515"
    t.index ["user_id", "foundation_proof_partition_id"], name: "index_fp_user_partitions_on_user_and_partition", unique: true
    t.index ["user_id"], name: "index_foundation_proof_user_partitions_on_user_id"
  end

  create_table "messaging_channel_deliveries", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "channel_key", null: false
    t.bigint "communication_id", null: false
    t.datetime "created_at", null: false
    t.integer "execution_attempt_count", default: 0, null: false
    t.datetime "execution_claimed_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["communication_id", "channel_key"], name: "index_messaging_channel_deliveries_on_comm_and_channel", unique: true
    t.index ["communication_id"], name: "index_messaging_channel_deliveries_on_communication_id"
    t.index ["status", "execution_claimed_at", "updated_at"], name: "index_messaging_channel_deliveries_on_execution_recovery"
  end

  create_table "messaging_communications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "accept_request_fingerprint"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.string "execution_handoff_status", null: false
    t.string "host_event_identity"
    t.text "metadata"
    t.string "notification_type_key", null: false
    t.string "status"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["status", "execution_handoff_status", "updated_at"], name: "index_messaging_communications_on_handoff_recovery"
    t.index ["user_id", "notification_type_key", "host_event_identity"], name: "index_messaging_communications_on_idempotency_namespace", unique: true
    t.index ["user_id"], name: "index_messaging_communications_on_user_id"
  end

  create_table "messaging_delivery_attempts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "channel_delivery_id", null: false
    t.datetime "created_at", null: false
    t.string "error_class"
    t.string "error_code"
    t.datetime "finished_at"
    t.string "normalized_provider_status"
    t.string "provider_message_id"
    t.datetime "started_at", null: false
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.index ["channel_delivery_id", "status"], name: "index_messaging_delivery_attempts_on_delivery_and_status"
    t.index ["channel_delivery_id"], name: "index_messaging_delivery_attempts_on_channel_delivery_id"
  end

  create_table "messaging_destination_plans", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "communication_id", null: false
    t.datetime "created_at", null: false
    t.text "decision"
    t.datetime "updated_at", null: false
    t.index ["communication_id"], name: "index_messaging_destination_plans_on_communication_id", unique: true
  end

  create_table "messaging_endpoint_pushover_credentials", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.text "application_token_ciphertext", null: false
    t.datetime "created_at", null: false
    t.integer "encryption_key_version", default: 1, null: false
    t.bigint "messaging_endpoint_id", null: false
    t.datetime "updated_at", null: false
    t.text "user_key_ciphertext", null: false
    t.index ["messaging_endpoint_id"], name: "index_messaging_pushover_credentials_on_endpoint_id", unique: true
  end

  create_table "messaging_endpoints", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "active_fingerprint"
    t.text "address_ciphertext"
    t.string "address_fingerprint", null: false
    t.string "channel_key", null: false
    t.datetime "created_at", null: false
    t.integer "encryption_key_version", default: 1, null: false
    t.datetime "last_successful_use_at"
    t.string "lifecycle_state", null: false
    t.integer "lock_version", default: 0, null: false
    t.string "masked_display_value", null: false
    t.datetime "revoked_at"
    t.string "single_active_slot"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.string "verification_state", null: false
    t.datetime "verified_at"
    t.index ["single_active_slot"], name: "index_messaging_endpoints_single_active_slot", unique: true
    t.index ["user_id", "channel_key", "active_fingerprint"], name: "index_messaging_endpoints_active_fingerprint", unique: true
    t.index ["user_id", "channel_key"], name: "index_messaging_endpoints_owner_channel"
    t.index ["user_id"], name: "index_messaging_endpoints_on_user_id"
    t.check_constraint "`lifecycle_state` in (_utf8mb4'active',_utf8mb4'revoked',_utf8mb4'invalid',_utf8mb4'retired')", name: "chk_messaging_endpoints_lifecycle"
    t.check_constraint "`verification_state` in (_utf8mb4'unverified',_utf8mb4'pending',_utf8mb4'verified',_utf8mb4'failed')", name: "chk_messaging_endpoints_verification"
  end

  create_table "messaging_inbox_items", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "archived_at"
    t.bigint "communication_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.datetime "viewed_at"
    t.index ["communication_id"], name: "index_messaging_inbox_items_on_communication_id", unique: true
    t.index ["deleted_at", "archived_at", "viewed_at"], name: "index_messaging_inbox_items_on_lifecycle"
  end

  create_table "messaging_notification_preferences", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "notification_type_key", null: false
    t.text "state", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "notification_type_key"], name: "index_messaging_notification_preferences_unique", unique: true
    t.index ["user_id"], name: "index_messaging_notification_preferences_on_user_id"
  end

  create_table "user_secrets", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "death_time"
    t.string "extra"
    t.string "reason"
    t.string "secret"
    t.datetime "updated_at", null: false
    t.integer "use_count", default: 0
    t.integer "use_count_max"
    t.bigint "user_id", null: false
    t.index ["secret"], name: "index_user_secrets_on_secret", unique: true
    t.index ["user_id"], name: "index_user_secrets_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "email", default: "", null: false
    t.boolean "email_validated", default: false
    t.string "first_name", default: "", null: false
    t.string "last_known_timezone"
    t.timestamp "last_known_timezone_update"
    t.datetime "last_login"
    t.string "last_login_strategy"
    t.string "last_name", default: "", null: false
    t.integer "password_consecutive_fail", default: 0
    t.string "password_digest", default: "", null: false
    t.string "phone_number"
    t.boolean "phone_number_validated", default: false, null: false
    t.string "recovery_password_digest", default: "", null: false
    t.string "roles", default: ""
    t.integer "successful_login", default: 0
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "verifier_token"
    t.datetime "verifier_token_last_reset"
    t.index ["deleted_at"], name: "index_users_on_deleted_at"
    t.index ["phone_number"], name: "index_users_on_phone_number", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "command_tower_impersonation_sessions", "users", column: "actor_user_id"
  add_foreign_key "command_tower_impersonation_sessions", "users", column: "target_user_id"
  add_foreign_key "messaging_channel_deliveries", "messaging_communications", column: "communication_id", on_delete: :cascade
  add_foreign_key "messaging_communications", "users"
  add_foreign_key "messaging_delivery_attempts", "messaging_channel_deliveries", column: "channel_delivery_id", on_delete: :cascade
  add_foreign_key "messaging_destination_plans", "messaging_communications", column: "communication_id", on_delete: :cascade
  add_foreign_key "messaging_endpoint_pushover_credentials", "messaging_endpoints", on_delete: :cascade
  add_foreign_key "messaging_endpoints", "users"
  add_foreign_key "messaging_inbox_items", "messaging_communications", column: "communication_id", on_delete: :cascade
  add_foreign_key "messaging_notification_preferences", "users"
  add_foreign_key "user_secrets", "users"
end

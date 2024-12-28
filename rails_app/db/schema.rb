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

ActiveRecord::Schema[7.2].define(version: 2024_12_04_065708) do
  create_table "user_secrets", charset: "utf8mb3", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "use_count", default: 0
    t.integer "use_count_max"
    t.string "reason"
    t.string "extra"
    t.string "secret"
    t.datetime "death_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["secret"], name: "index_user_secrets_on_secret", unique: true
    t.index ["user_id"], name: "index_user_secrets_on_user_id"
  end

  create_table "users", charset: "utf8mb3", force: :cascade do |t|
    t.string "first_name", default: "", null: false
    t.string "last_name", default: "", null: false
    t.string "username"
    t.string "last_known_timezone"
    t.timestamp "last_known_timezone_update"
    t.integer "successful_login", default: 0
    t.string "last_login_strategy"
    t.datetime "last_login"
    t.string "verifier_token"
    t.datetime "verifier_token_last_reset"
    t.string "email", default: "", null: false
    t.boolean "email_validated", default: false
    t.integer "password_consecutive_fail", default: 0
    t.string "password_digest", default: "", null: false
    t.string "recovery_password_digest", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "user_secrets", "users"
end

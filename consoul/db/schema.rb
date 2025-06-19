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

ActiveRecord::Schema[7.2].define(version: 2025_06_19_133015) do
  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "title", null: false
    t.string "status", default: "waiting", null: false
    t.datetime "started_at"
    t.datetime "ended_at"
    t.integer "timer_seconds", default: 0, null: false
    t.boolean "timer_running", default: false, null: false
    t.datetime "timer_started_at"
    t.integer "heart_count", default: 0, null: false
    t.bigint "user1_id", null: false
    t.bigint "user2_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sessions_on_created_at"
    t.index ["status"], name: "index_sessions_on_status"
    t.index ["user1_id", "user2_id"], name: "index_sessions_on_user1_id_and_user2_id"
    t.index ["user1_id"], name: "index_sessions_on_user1_id"
    t.index ["user2_id"], name: "index_sessions_on_user2_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pair_user_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["pair_user_id"], name: "index_users_on_pair_user_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "sessions", "users", column: "user1_id"
  add_foreign_key "sessions", "users", column: "user2_id"
  add_foreign_key "users", "users", column: "pair_user_id"
end

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

ActiveRecord::Schema[7.1].define(version: 2025_08_31_124802) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "game_sessions", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "map_name"
    t.boolean "online", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["player_id"], name: "index_game_sessions_on_player_id", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.string "platform_name"
    t.string "in_game_name"
    t.string "eos_id"
    t.string "tribe_id"
    t.string "tribe_name"
    t.string "discord_name"
    t.string "discord_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "votes_count"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "votes", force: :cascade do |t|
    t.bigint "player_id", null: false
    t.string "source", default: "topserveur"
    t.integer "points_awarded", default: 100
    t.boolean "processed", default: false
    t.string "map_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "vote_valid"
    t.index ["player_id", "created_at"], name: "index_votes_on_player_id_and_created_at"
    t.index ["player_id"], name: "index_votes_on_player_id"
  end

  add_foreign_key "game_sessions", "players"
  add_foreign_key "votes", "players"
end

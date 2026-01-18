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

ActiveRecord::Schema[8.1].define(version: 2026_01_18_153454) do
  create_table "ai_suggestions", force: :cascade do |t|
    t.datetime "acted_at"
    t.integer "card_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.string "field_name"
    t.string "provider"
    t.string "status", default: "pending"
    t.string "suggestion_type", null: false
    t.datetime "updated_at", null: false
    t.index ["card_id", "status"], name: "index_ai_suggestions_on_card_id_and_status"
    t.index ["card_id"], name: "index_ai_suggestions_on_card_id"
    t.index ["suggestion_type"], name: "index_ai_suggestions_on_suggestion_type"
  end

  create_table "board_activities", force: :cascade do |t|
    t.string "activity_type", null: false
    t.integer "board_id", null: false
    t.integer "card_id"
    t.datetime "created_at", null: false
    t.datetime "last_active_at"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["activity_type"], name: "index_board_activities_on_activity_type"
    t.index ["board_id", "user_id"], name: "index_board_activities_on_board_id_and_user_id"
    t.index ["board_id"], name: "index_board_activities_on_board_id"
    t.index ["card_id"], name: "index_board_activities_on_card_id"
    t.index ["user_id"], name: "index_board_activities_on_user_id"
  end

  create_table "board_members", force: :cascade do |t|
    t.integer "board_id", null: false
    t.datetime "created_at", null: false
    t.string "role", default: "viewer"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["board_id", "user_id"], name: "index_board_members_on_board_id_and_user_id", unique: true
    t.index ["board_id"], name: "index_board_members_on_board_id"
    t.index ["role"], name: "index_board_members_on_role"
    t.index ["user_id"], name: "index_board_members_on_user_id"
  end

  create_table "boards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "level", default: "personal"
    t.string "name", null: false
    t.integer "owner_id", null: false
    t.datetime "updated_at", null: false
    t.index ["level"], name: "index_boards_on_level"
    t.index ["owner_id"], name: "index_boards_on_owner_id"
  end

  create_table "card_assignments", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["card_id", "user_id"], name: "index_card_assignments_on_card_id_and_user_id", unique: true
    t.index ["card_id"], name: "index_card_assignments_on_card_id"
    t.index ["user_id"], name: "index_card_assignments_on_user_id"
  end

  create_table "cards", force: :cascade do |t|
    t.datetime "ai_analyzed_at"
    t.text "ai_summary"
    t.integer "board_id", null: false
    t.json "card_metadata", default: {}
    t.string "card_type", default: "task", null: false
    t.integer "column_id", null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id", null: false
    t.text "description"
    t.date "due_date"
    t.integer "position", default: 0
    t.string "priority", default: "medium"
    t.string "title", null: false
    t.string "type_inference_confidence"
    t.datetime "type_inferred_at"
    t.datetime "updated_at", null: false
    t.index ["board_id"], name: "index_cards_on_board_id"
    t.index ["card_type"], name: "index_cards_on_card_type"
    t.index ["column_id", "position"], name: "index_cards_on_column_id_and_position"
    t.index ["column_id"], name: "index_cards_on_column_id"
    t.index ["created_by_id"], name: "index_cards_on_created_by_id"
    t.index ["priority"], name: "index_cards_on_priority"
  end

  create_table "columns", force: :cascade do |t|
    t.integer "board_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0
    t.datetime "updated_at", null: false
    t.index ["board_id", "position"], name: "index_columns_on_board_id_and_position"
    t.index ["board_id"], name: "index_columns_on_board_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.datetime "last_signed_in_at"
    t.string "login_method", default: "email"
    t.string "name", null: false
    t.string "open_id", null: false
    t.string "role", default: "user"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["open_id"], name: "index_users_on_open_id", unique: true
  end

  add_foreign_key "ai_suggestions", "cards"
  add_foreign_key "board_activities", "boards"
  add_foreign_key "board_activities", "cards"
  add_foreign_key "board_activities", "users"
  add_foreign_key "board_members", "boards"
  add_foreign_key "board_members", "users"
  add_foreign_key "boards", "users", column: "owner_id"
  add_foreign_key "card_assignments", "cards"
  add_foreign_key "card_assignments", "users"
  add_foreign_key "cards", "boards"
  add_foreign_key "cards", "columns"
  add_foreign_key "cards", "users", column: "created_by_id"
  add_foreign_key "columns", "boards"
end

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

ActiveRecord::Schema[8.1].define(version: 2026_01_18_230002) do
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

  create_table "card_facts", force: :cascade do |t|
    t.integer "card_id", null: false
    t.datetime "created_at", null: false
    t.integer "fact_id", null: false
    t.string "role", default: "source", null: false
    t.string "source_field"
    t.integer "text_offset_end"
    t.integer "text_offset_start"
    t.datetime "updated_at", null: false
    t.index ["card_id", "fact_id", "role"], name: "index_card_facts_on_card_id_and_fact_id_and_role", unique: true
    t.index ["card_id"], name: "index_card_facts_on_card_id"
    t.index ["fact_id"], name: "index_card_facts_on_fact_id"
    t.index ["role"], name: "index_card_facts_on_role"
  end

  create_table "card_relationships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.string "relationship_type", null: false
    t.integer "source_card_id", null: false
    t.integer "target_card_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_card_relationships_on_created_by_id"
    t.index ["relationship_type"], name: "index_card_relationships_on_relationship_type"
    t.index ["source_card_id", "target_card_id", "relationship_type"], name: "idx_card_relationships_unique", unique: true
    t.index ["source_card_id"], name: "index_card_relationships_on_source_card_id"
    t.index ["target_card_id"], name: "index_card_relationships_on_target_card_id"
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

  create_table "domains", force: :cascade do |t|
    t.integer "board_id", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "icon"
    t.string "name", null: false
    t.integer "parent_domain_id"
    t.boolean "system_generated", default: false
    t.datetime "updated_at", null: false
    t.index ["board_id", "name"], name: "index_domains_on_board_id_and_name", unique: true
    t.index ["board_id"], name: "index_domains_on_board_id"
    t.index ["parent_domain_id"], name: "index_domains_on_parent_domain_id"
  end

  create_table "entities", force: :cascade do |t|
    t.json "aliases", default: []
    t.float "confidence", default: 1.0
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "description"
    t.integer "domain_id", null: false
    t.string "entity_type", null: false
    t.string "external_id"
    t.string "external_source"
    t.string "name", null: false
    t.json "properties", default: {}
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_entities_on_created_by_id"
    t.index ["domain_id", "name"], name: "index_entities_on_domain_id_and_name", unique: true
    t.index ["domain_id"], name: "index_entities_on_domain_id"
    t.index ["entity_type"], name: "index_entities_on_entity_type"
    t.index ["external_source", "external_id"], name: "index_entities_on_external_source_and_external_id", unique: true, where: "external_id IS NOT NULL"
  end

  create_table "entity_mentions", force: :cascade do |t|
    t.integer "card_id", null: false
    t.float "confidence", default: 1.0
    t.datetime "created_at", null: false
    t.integer "entity_id", null: false
    t.string "extraction_method"
    t.string "mention_text", null: false
    t.string "source_field", null: false
    t.integer "text_offset_end"
    t.integer "text_offset_start"
    t.datetime "updated_at", null: false
    t.index ["card_id", "entity_id"], name: "index_entity_mentions_on_card_id_and_entity_id"
    t.index ["card_id"], name: "index_entity_mentions_on_card_id"
    t.index ["entity_id"], name: "index_entity_mentions_on_entity_id"
    t.index ["mention_text"], name: "index_entity_mentions_on_mention_text"
  end

  create_table "facts", force: :cascade do |t|
    t.float "confidence", default: 1.0
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.integer "domain_id", null: false
    t.string "extraction_method"
    t.boolean "negated", default: false
    t.integer "object_entity_id"
    t.string "object_type"
    t.string "object_value"
    t.string "predicate", null: false
    t.integer "subject_entity_id", null: false
    t.datetime "updated_at", null: false
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.index ["created_by_id"], name: "index_facts_on_created_by_id"
    t.index ["domain_id"], name: "index_facts_on_domain_id"
    t.index ["extraction_method"], name: "index_facts_on_extraction_method"
    t.index ["object_entity_id"], name: "index_facts_on_object_entity_id"
    t.index ["predicate"], name: "index_facts_on_predicate"
    t.index ["subject_entity_id", "predicate", "object_entity_id"], name: "idx_facts_unique_entity_relationship", unique: true, where: "object_entity_id IS NOT NULL AND valid_until IS NULL"
    t.index ["subject_entity_id", "predicate", "object_value"], name: "idx_facts_unique_value_relationship", unique: true, where: "object_value IS NOT NULL AND valid_until IS NULL"
    t.index ["subject_entity_id"], name: "index_facts_on_subject_entity_id"
  end

  create_table "llm_configurations", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "api_key"
    t.datetime "created_at", null: false
    t.boolean "default_for_type", default: false, null: false
    t.string "endpoint"
    t.string "model", null: false
    t.string "name", null: false
    t.json "options", default: {}
    t.integer "priority", default: 0, null: false
    t.string "provider_type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["active"], name: "index_llm_configurations_on_active"
    t.index ["provider_type", "default_for_type"], name: "index_llm_configurations_on_provider_type_and_default_for_type", unique: true, where: "default_for_type = true"
    t.index ["provider_type"], name: "index_llm_configurations_on_provider_type"
    t.index ["user_id", "name"], name: "index_llm_configurations_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_llm_configurations_on_user_id"
  end

  create_table "user_settings", force: :cascade do |t|
    t.string "active_provider", default: "local", null: false
    t.datetime "created_at", null: false
    t.string "local_api_key"
    t.string "local_endpoint", default: "http://localhost:11434/v1"
    t.string "local_model", default: "llama3.2"
    t.string "remote_api_key"
    t.string "remote_endpoint"
    t.string "remote_model", default: "gpt-4o-mini"
    t.string "remote_provider", default: "openai"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_user_settings_on_user_id", unique: true
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
  add_foreign_key "card_facts", "cards"
  add_foreign_key "card_facts", "facts"
  add_foreign_key "card_relationships", "cards", column: "source_card_id"
  add_foreign_key "card_relationships", "cards", column: "target_card_id"
  add_foreign_key "card_relationships", "users", column: "created_by_id"
  add_foreign_key "cards", "boards"
  add_foreign_key "cards", "columns"
  add_foreign_key "cards", "users", column: "created_by_id"
  add_foreign_key "columns", "boards"
  add_foreign_key "domains", "boards"
  add_foreign_key "domains", "domains", column: "parent_domain_id"
  add_foreign_key "entities", "domains"
  add_foreign_key "entities", "users", column: "created_by_id"
  add_foreign_key "entity_mentions", "cards"
  add_foreign_key "entity_mentions", "entities"
  add_foreign_key "facts", "domains"
  add_foreign_key "facts", "entities", column: "object_entity_id"
  add_foreign_key "facts", "entities", column: "subject_entity_id"
  add_foreign_key "facts", "users", column: "created_by_id"
  add_foreign_key "llm_configurations", "users"
  add_foreign_key "user_settings", "users"
end

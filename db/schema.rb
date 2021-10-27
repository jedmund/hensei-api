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

ActiveRecord::Schema.define(version: 2020_10_19_103224) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "pgcrypto"
  enable_extension "plpgsql"

  create_table "characters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.string "granblue_id"
    t.integer "rarity"
    t.integer "element"
    t.integer "proficiency1"
    t.integer "proficiency2"
    t.integer "gender"
    t.integer "race1"
    t.integer "race2"
    t.boolean "flb"
    t.boolean "max_level"
    t.integer "min_hp"
    t.integer "max_hp"
    t.integer "max_hp_flb"
    t.integer "min_atk"
    t.integer "max_atk"
    t.integer "max_atk_flb"
    t.integer "base_da"
    t.integer "base_ta"
    t.float "ougi_ratio"
    t.float "ougi_ratio_flb"
  end

  create_table "grid_characters", force: :cascade do |t|
    t.uuid "party_id"
    t.uuid "character_id"
    t.integer "uncap_level"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["character_id"], name: "index_grid_characters_on_character_id"
    t.index ["party_id"], name: "index_grid_characters_on_party_id"
  end

  create_table "grid_summons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "party_id"
    t.uuid "summon_id"
    t.integer "uncap_level"
    t.boolean "main"
    t.boolean "friend"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["party_id"], name: "index_grid_summons_on_party_id"
    t.index ["summon_id"], name: "index_grid_summons_on_summon_id"
  end

  create_table "grid_weapons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "party_id"
    t.uuid "weapon_id"
    t.uuid "weapon_key1_id"
    t.uuid "weapon_key2_id"
    t.integer "uncap_level"
    t.boolean "mainhand"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["party_id"], name: "index_grid_weapons_on_party_id"
    t.index ["weapon_id"], name: "index_grid_weapons_on_weapon_id"
    t.index ["weapon_key1_id"], name: "index_grid_weapons_on_weapon_key1_id"
    t.index ["weapon_key2_id"], name: "index_grid_weapons_on_weapon_key2_id"
  end

  create_table "oauth_access_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "resource_owner_id", null: false
    t.uuid "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "scopes"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "resource_owner_id"
    t.uuid "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.string "scopes"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_tokens_on_token", unique: true
  end

  create_table "oauth_applications", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "parties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "shortcode"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["user_id"], name: "index_parties_on_user_id"
  end

  create_table "summons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.string "granblue_id"
    t.integer "rarity"
    t.integer "element"
    t.string "series"
    t.boolean "flb"
    t.boolean "ulb"
    t.integer "max_level"
    t.integer "min_hp"
    t.integer "max_hp"
    t.integer "max_hp_flb"
    t.integer "max_hp_ulb"
    t.integer "min_atk"
    t.integer "max_atk"
    t.integer "max_atk_flb"
    t.integer "max_atk_ulb"
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "username"
    t.integer "granblue_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "weapon_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "series"
    t.integer "type"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "weapons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.string "granblue_id"
    t.integer "rarity"
    t.integer "element"
    t.integer "proficiency"
    t.string "series"
    t.boolean "flb"
    t.boolean "ulb"
    t.integer "max_level"
    t.integer "max_skill_level"
    t.integer "min_hp"
    t.integer "max_hp"
    t.integer "max_hp_flb"
    t.integer "max_hp_ulb"
    t.integer "min_atk"
    t.integer "max_atk"
    t.integer "max_atk_flb"
    t.integer "max_atk_ulb"
  end

  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
end

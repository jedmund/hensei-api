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

ActiveRecord::Schema.define(version: 2022_12_26_054501) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "pg_trgm"
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
    t.boolean "flb", default: false, null: false
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
    t.boolean "special", default: false, null: false
    t.boolean "ulb", default: false, null: false
    t.integer "max_hp_ulb"
    t.integer "max_atk_ulb"
    t.integer "character_id", default: [], null: false, array: true
    t.index ["name_en"], name: "index_characters_on_name_en", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "favorites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "party_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["party_id"], name: "index_favorites_on_party_id"
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "grid_characters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "party_id"
    t.uuid "character_id"
    t.integer "uncap_level"
    t.integer "position"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.boolean "perpetuity", default: false, null: false
    t.integer "awakening_type", default: 0, null: false
    t.integer "awakening_level", default: 1, null: false
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
    t.uuid "weapon_key3_id"
    t.integer "ax_modifier1"
    t.float "ax_strength1"
    t.integer "ax_modifier2"
    t.float "ax_strength2"
    t.integer "element"
    t.integer "awakening_type"
    t.integer "awakening_level", default: 1, null: false
    t.index ["party_id"], name: "index_grid_weapons_on_party_id"
    t.index ["weapon_id"], name: "index_grid_weapons_on_weapon_id"
  end

  create_table "job_skills", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "job_id"
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "slug", null: false
    t.integer "color", null: false
    t.boolean "main", default: false
    t.boolean "sub", default: false
    t.boolean "emp", default: false
    t.integer "order"
    t.boolean "base", default: false
    t.index ["job_id"], name: "index_job_skills_on_job_id"
  end

  create_table "jobs", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "proficiency1"
    t.integer "proficiency2"
    t.string "row"
    t.boolean "ml", default: false
    t.integer "order"
    t.uuid "base_job_id"
    t.index ["base_job_id"], name: "index_jobs_on_base_job_id"
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
    t.boolean "extra", default: false, null: false
    t.string "name"
    t.text "description"
    t.uuid "raid_id"
    t.integer "element"
    t.integer "weapons_count"
    t.uuid "job_id"
    t.integer "ml"
    t.uuid "skill1_id"
    t.uuid "skill2_id"
    t.uuid "skill3_id"
    t.uuid "skill0_id"
    t.index ["job_id"], name: "index_parties_on_job_id"
    t.index ["skill0_id"], name: "index_parties_on_skill0_id"
    t.index ["skill1_id"], name: "index_parties_on_skill1_id"
    t.index ["skill2_id"], name: "index_parties_on_skill2_id"
    t.index ["skill3_id"], name: "index_parties_on_skill3_id"
    t.index ["user_id"], name: "index_parties_on_user_id"
  end

  create_table "raids", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "level"
    t.integer "group"
    t.integer "element"
    t.string "slug"
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
    t.boolean "subaura", default: false, null: false
    t.integer "limit"
    t.index ["name_en"], name: "index_summons_on_name_en", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "username"
    t.integer "granblue_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.string "picture", default: "gran"
    t.string "language", default: "en", null: false
    t.boolean "private", default: false, null: false
    t.string "element", default: "water", null: false
    t.integer "gender", default: 0, null: false
    t.string "theme", default: "system", null: false
  end

  create_table "weapon_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "series"
    t.integer "slot"
    t.integer "group"
    t.integer "order"
    t.string "slug"
  end

  create_table "weapons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.string "granblue_id"
    t.integer "rarity"
    t.integer "element"
    t.integer "proficiency"
    t.integer "series", default: -1, null: false
    t.boolean "flb", default: false, null: false
    t.boolean "ulb", default: false, null: false
    t.integer "max_level", default: 100, null: false
    t.integer "max_skill_level", default: 10, null: false
    t.integer "min_hp"
    t.integer "max_hp"
    t.integer "max_hp_flb"
    t.integer "max_hp_ulb"
    t.integer "min_atk"
    t.integer "max_atk"
    t.integer "max_atk_flb"
    t.integer "max_atk_ulb"
    t.boolean "extra", default: false, null: false
    t.integer "limit"
    t.integer "ax", default: 0, null: false
    t.boolean "awakening", default: true, null: false
    t.index ["name_en"], name: "index_weapons_on_name_en", opclass: :gin_trgm_ops, using: :gin
  end

  add_foreign_key "favorites", "parties"
  add_foreign_key "favorites", "users"
  add_foreign_key "grid_characters", "characters"
  add_foreign_key "grid_characters", "parties"
  add_foreign_key "grid_summons", "parties"
  add_foreign_key "grid_summons", "summons"
  add_foreign_key "grid_weapons", "parties"
  add_foreign_key "grid_weapons", "weapon_keys", column: "weapon_key3_id"
  add_foreign_key "grid_weapons", "weapons"
  add_foreign_key "jobs", "jobs", column: "base_job_id"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "parties", "job_skills", column: "skill0_id"
  add_foreign_key "parties", "job_skills", column: "skill1_id"
  add_foreign_key "parties", "job_skills", column: "skill2_id"
  add_foreign_key "parties", "job_skills", column: "skill3_id"
  add_foreign_key "parties", "jobs"
  add_foreign_key "parties", "raids"
  add_foreign_key "parties", "users"
end

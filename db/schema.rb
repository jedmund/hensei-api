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

ActiveRecord::Schema[7.0].define(version: 2025_01_10_070255) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"
  enable_extension "plpgsql"
  enable_extension "uuid-ossp"

  create_table "app_updates", primary_key: "updated_at", id: :datetime, force: :cascade do |t|
    t.string "update_type", null: false
    t.string "version"
  end

  create_table "awakenings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "slug", null: false
    t.string "object_type", null: false
    t.integer "order", default: 0, null: false
  end

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
    t.string "wiki_en", default: "", null: false
    t.date "release_date"
    t.date "flb_date"
    t.date "ulb_date"
    t.string "wiki_ja", default: ""
    t.string "gamewith", default: ""
    t.string "kamigame", default: ""
    t.string "nicknames_en", default: [], null: false, array: true
    t.string "nicknames_jp", default: [], null: false, array: true
    t.index ["name_en"], name: "index_characters_on_name_en", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "data_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "filename", null: false
    t.datetime "imported_at", null: false
    t.index ["filename"], name: "index_data_versions_on_filename", unique: true
  end

  create_table "favorites", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.uuid "party_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["party_id"], name: "index_favorites_on_party_id"
    t.index ["user_id"], name: "index_favorites_on_user_id"
  end

  create_table "gacha", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.boolean "premium"
    t.boolean "classic"
    t.boolean "flash"
    t.boolean "legend"
    t.boolean "valentines"
    t.boolean "summer"
    t.boolean "halloween"
    t.boolean "holiday"
    t.string "drawable_type"
    t.uuid "drawable_id"
    t.index ["drawable_id"], name: "index_gacha_on_drawable_id", unique: true
    t.index ["drawable_type", "drawable_id"], name: "index_gacha_on_drawable"
  end

  create_table "gacha_rateups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "gacha_id"
    t.string "user_id"
    t.decimal "rate"
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.index ["gacha_id"], name: "index_gacha_rateups_on_gacha_id"
  end

  create_table "grid_characters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "party_id"
    t.uuid "character_id"
    t.integer "uncap_level"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "perpetuity", default: false, null: false
    t.integer "transcendence_step", default: 0, null: false
    t.jsonb "ring1", default: {"modifier"=>nil, "strength"=>nil}, null: false
    t.jsonb "ring2", default: {"modifier"=>nil, "strength"=>nil}, null: false
    t.jsonb "ring3", default: {"modifier"=>nil, "strength"=>nil}, null: false
    t.jsonb "ring4", default: {"modifier"=>nil, "strength"=>nil}, null: false
    t.jsonb "earring", default: {"modifier"=>nil, "strength"=>nil}, null: false
    t.uuid "awakening_id"
    t.integer "awakening_level", default: 1
    t.index ["awakening_id"], name: "index_grid_characters_on_awakening_id"
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "transcendence_step", default: 0, null: false
    t.boolean "quick_summon", default: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "weapon_key3_id"
    t.integer "ax_modifier1"
    t.float "ax_strength1"
    t.integer "ax_modifier2"
    t.float "ax_strength2"
    t.integer "element"
    t.integer "awakening_level", default: 1, null: false
    t.uuid "awakening_id"
    t.integer "transcendence_step", default: 0
    t.string "weapon_key4_id"
    t.index ["awakening_id"], name: "index_grid_weapons_on_awakening_id"
    t.index ["party_id"], name: "index_grid_weapons_on_party_id"
    t.index ["weapon_id"], name: "index_grid_weapons_on_weapon_id"
    t.index ["weapon_key1_id"], name: "index_grid_weapons_on_weapon_key1_id"
    t.index ["weapon_key2_id"], name: "index_grid_weapons_on_weapon_key2_id"
    t.index ["weapon_key3_id"], name: "index_grid_weapons_on_weapon_key3_id"
  end

  create_table "guidebooks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "granblue_id", null: false
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "description_en", null: false
    t.string "description_jp", null: false
    t.datetime "created_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
  end

  create_table "job_accessories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "job_id"
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "granblue_id", null: false
    t.integer "rarity"
    t.date "release_date"
    t.integer "accessory_type"
    t.index ["job_id"], name: "index_job_accessories_on_job_id"
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
    t.boolean "master_level", default: false, null: false
    t.integer "order"
    t.uuid "base_job_id"
    t.string "granblue_id"
    t.boolean "accessory", default: false
    t.integer "accessory_type", default: 0
    t.boolean "ultimate_mastery", default: false, null: false
    t.index ["base_job_id"], name: "index_jobs_on_base_job_id"
  end

  create_table "oauth_access_grants", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "resource_owner_id", null: false
    t.uuid "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.datetime "created_at", precision: nil, null: false
    t.datetime "revoked_at", precision: nil
    t.string "scopes"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "resource_owner_id"
    t.uuid "application_id"
    t.string "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.datetime "revoked_at", precision: nil
    t.datetime "created_at", precision: nil, null: false
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
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
  end

  create_table "parties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id"
    t.string "shortcode"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "extra", default: false, null: false
    t.string "name"
    t.text "description"
    t.uuid "raid_id"
    t.integer "element"
    t.integer "weapons_count", default: 0
    t.uuid "job_id"
    t.integer "master_level"
    t.uuid "skill1_id"
    t.uuid "skill2_id"
    t.uuid "skill3_id"
    t.uuid "skill0_id"
    t.boolean "full_auto", default: false, null: false
    t.boolean "auto_guard", default: false, null: false
    t.boolean "charge_attack", default: true, null: false
    t.integer "clear_time", default: 0, null: false
    t.integer "button_count"
    t.integer "chain_count"
    t.integer "turn_count"
    t.uuid "source_party_id"
    t.uuid "accessory_id"
    t.integer "characters_count", default: 0
    t.integer "summons_count", default: 0
    t.string "edit_key"
    t.uuid "local_id"
    t.integer "ultimate_mastery"
    t.uuid "guidebook3_id"
    t.uuid "guidebook1_id"
    t.uuid "guidebook2_id"
    t.boolean "auto_summon", default: false
    t.boolean "remix", default: false, null: false
    t.integer "visibility", default: 1, null: false
    t.index ["accessory_id"], name: "index_parties_on_accessory_id"
    t.index ["guidebook1_id"], name: "index_parties_on_guidebook1_id"
    t.index ["guidebook2_id"], name: "index_parties_on_guidebook2_id"
    t.index ["guidebook3_id"], name: "index_parties_on_guidebook3_id"
    t.index ["job_id"], name: "index_parties_on_job_id"
    t.index ["skill0_id"], name: "index_parties_on_skill0_id"
    t.index ["skill1_id"], name: "index_parties_on_skill1_id"
    t.index ["skill2_id"], name: "index_parties_on_skill2_id"
    t.index ["skill3_id"], name: "index_parties_on_skill3_id"
    t.index ["source_party_id"], name: "index_parties_on_source_party_id"
    t.index ["user_id"], name: "index_parties_on_user_id"
  end

  create_table "pg_search_documents", force: :cascade do |t|
    t.text "content"
    t.string "granblue_id"
    t.string "name_en"
    t.string "name_jp"
    t.integer "element"
    t.string "searchable_type"
    t.uuid "searchable_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["searchable_type", "searchable_id"], name: "index_pg_search_documents_on_searchable"
  end

  create_table "raid_groups", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.integer "difficulty"
    t.integer "order", null: false
    t.integer "section", default: 1, null: false
    t.boolean "extra", default: false, null: false
    t.boolean "hl", default: true, null: false
    t.boolean "guidebooks", default: false, null: false
  end

  create_table "raids", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "level"
    t.integer "element"
    t.string "slug"
    t.uuid "group_id"
    t.index ["group_id"], name: "index_raids_on_group_id"
  end

  create_table "sparks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "user_id", null: false
    t.string "guild_ids", null: false, array: true
    t.integer "crystals", default: 0
    t.integer "tickets", default: 0
    t.integer "ten_tickets", default: 0
    t.string "target_type"
    t.bigint "target_id"
    t.datetime "updated_at", default: -> { "CURRENT_TIMESTAMP" }, null: false
    t.string "target_memo"
    t.index ["target_type", "target_id"], name: "index_sparks_on_target"
    t.index ["user_id"], name: "index_sparks_on_user_id", unique: true
  end

  create_table "summons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.string "granblue_id"
    t.integer "rarity"
    t.integer "element"
    t.string "series"
    t.boolean "flb", default: false, null: false
    t.boolean "ulb", default: false, null: false
    t.integer "max_level", default: 100, null: false
    t.integer "min_hp"
    t.integer "max_hp"
    t.integer "max_hp_flb"
    t.integer "max_hp_ulb"
    t.integer "min_atk"
    t.integer "max_atk"
    t.integer "max_atk_flb"
    t.integer "max_atk_ulb"
    t.boolean "subaura", default: false, null: false
    t.boolean "limit", default: false, null: false
    t.boolean "transcendence", default: false, null: false
    t.integer "max_atk_xlb"
    t.integer "max_hp_xlb"
    t.integer "summon_id"
    t.date "release_date"
    t.date "flb_date"
    t.date "ulb_date"
    t.string "wiki_en", default: ""
    t.string "wiki_ja", default: ""
    t.string "gamewith", default: ""
    t.string "kamigame", default: ""
    t.date "transcendence_date"
    t.string "nicknames_en", default: [], null: false, array: true
    t.string "nicknames_jp", default: [], null: false, array: true
    t.index ["name_en"], name: "index_summons_on_name_en", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "users", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "email"
    t.string "password_digest"
    t.string "username"
    t.integer "granblue_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "picture", default: "gran"
    t.string "language", default: "en", null: false
    t.boolean "private", default: false, null: false
    t.string "element", default: "water", null: false
    t.integer "gender", default: 0, null: false
    t.string "theme", default: "system", null: false
    t.integer "role", default: 1, null: false
  end

  create_table "weapon_awakenings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "weapon_id", null: false
    t.uuid "awakening_id", null: false
    t.index ["awakening_id"], name: "index_weapon_awakenings_on_awakening_id"
    t.index ["weapon_id"], name: "index_weapon_awakenings_on_weapon_id"
  end

  create_table "weapon_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "slot"
    t.integer "group"
    t.integer "order"
    t.string "slug"
    t.integer "granblue_id"
    t.integer "series", default: [], null: false, array: true
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
    t.integer "ax_type"
    t.boolean "limit", default: false, null: false
    t.boolean "ax", default: false, null: false
    t.uuid "recruits_id"
    t.integer "max_awakening_level"
    t.date "release_date"
    t.date "flb_date"
    t.date "ulb_date"
    t.string "wiki_en", default: ""
    t.string "wiki_ja", default: ""
    t.string "gamewith", default: ""
    t.string "kamigame", default: ""
    t.string "nicknames_en", default: [], null: false, array: true
    t.string "nicknames_jp", default: [], null: false, array: true
    t.boolean "transcendence", default: false
    t.date "transcendence_date"
    t.index ["name_en"], name: "index_weapons_on_name_en", opclass: :gin_trgm_ops, using: :gin
    t.index ["recruits_id"], name: "index_weapons_on_recruits_id"
  end

  add_foreign_key "favorites", "parties"
  add_foreign_key "favorites", "users"
  add_foreign_key "grid_characters", "awakenings"
  add_foreign_key "grid_characters", "characters"
  add_foreign_key "grid_characters", "parties"
  add_foreign_key "grid_summons", "parties"
  add_foreign_key "grid_summons", "summons"
  add_foreign_key "grid_weapons", "awakenings"
  add_foreign_key "grid_weapons", "parties"
  add_foreign_key "grid_weapons", "weapon_keys", column: "weapon_key3_id"
  add_foreign_key "grid_weapons", "weapons"
  add_foreign_key "jobs", "jobs", column: "base_job_id"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "parties", "guidebooks", column: "guidebook1_id"
  add_foreign_key "parties", "guidebooks", column: "guidebook2_id"
  add_foreign_key "parties", "guidebooks", column: "guidebook3_id"
  add_foreign_key "parties", "job_accessories", column: "accessory_id"
  add_foreign_key "parties", "job_skills", column: "skill0_id"
  add_foreign_key "parties", "job_skills", column: "skill1_id"
  add_foreign_key "parties", "job_skills", column: "skill2_id"
  add_foreign_key "parties", "job_skills", column: "skill3_id"
  add_foreign_key "parties", "jobs"
  add_foreign_key "parties", "raids"
  add_foreign_key "parties", "users"
  add_foreign_key "raids", "raid_groups", column: "group_id"
  add_foreign_key "weapon_awakenings", "awakenings"
  add_foreign_key "weapon_awakenings", "weapons"
end

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

ActiveRecord::Schema[8.0].define(version: 2026_03_17_002851) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gin"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"
  enable_extension "pg_trgm"
  enable_extension "pgcrypto"

  create_table "app_updates", primary_key: "updated_at", id: :datetime, force: :cascade do |t|
    t.string "update_type", null: false
    t.string "version"
  end

  create_table "artifact_skills", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "skill_group", null: false
    t.integer "modifier", null: false
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.jsonb "base_values", default: [], null: false
    t.decimal "growth", precision: 15, scale: 2
    t.string "suffix_en", default: ""
    t.string "suffix_jp", default: ""
    t.string "polarity", default: "positive", null: false
    t.string "game_name_en"
    t.string "game_name_jp"
    t.integer "score_category"
    t.index ["game_name_en"], name: "index_artifact_skills_on_game_name_en"
    t.index ["game_name_jp"], name: "index_artifact_skills_on_game_name_jp"
    t.index ["skill_group", "modifier"], name: "index_artifact_skills_on_skill_group_and_modifier", unique: true
    t.index ["skill_group"], name: "index_artifact_skills_on_skill_group"
  end

  create_table "artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "granblue_id", null: false
    t.string "name_en", null: false
    t.string "name_jp"
    t.integer "proficiency"
    t.integer "rarity", default: 0, null: false
    t.date "release_date"
    t.index ["granblue_id"], name: "index_artifacts_on_granblue_id", unique: true
    t.index ["proficiency"], name: "index_artifacts_on_proficiency"
    t.index ["rarity"], name: "index_artifacts_on_rarity"
  end

  create_table "awakenings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "slug", null: false
    t.string "object_type", null: false
    t.integer "order", default: 0, null: false
  end

  create_table "character_series", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "slug", null: false
    t.integer "order", default: 0, null: false
    t.index ["order"], name: "index_character_series_on_order"
    t.index ["slug"], name: "index_character_series_on_slug", unique: true
  end

  create_table "character_series_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "character_id", null: false
    t.uuid "character_series_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id", "character_series_id"], name: "idx_char_series_membership_unique", unique: true
    t.index ["character_id"], name: "index_character_series_memberships_on_character_id"
    t.index ["character_series_id"], name: "index_character_series_memberships_on_character_series_id"
  end

  create_table "character_skills", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "character_granblue_id", null: false
    t.uuid "skill_id", null: false
    t.integer "position", null: false
    t.integer "unlock_level"
    t.integer "improve_level"
    t.uuid "alt_skill_id"
    t.text "alt_condition"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alt_skill_id"], name: "index_character_skills_on_alt_skill_id"
    t.index ["character_granblue_id", "position"], name: "index_character_skills_on_character_granblue_id_and_position"
    t.index ["character_granblue_id"], name: "index_character_skills_on_character_granblue_id"
    t.index ["skill_id"], name: "index_character_skills_on_skill_id"
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
    t.text "wiki_raw"
    t.jsonb "game_raw_en", comment: "JSON data from game (English)"
    t.jsonb "game_raw_jp", comment: "JSON data from game (Japanese)"
    t.integer "season"
    t.integer "series", default: [], null: false, array: true
    t.boolean "style_swap", default: false, null: false
    t.string "style_name_en"
    t.string "style_name_jp"
    t.index ["granblue_id"], name: "index_characters_on_granblue_id"
    t.index ["name_en"], name: "index_characters_on_name_en", opclass: :gin_trgm_ops, using: :gin
    t.index ["season"], name: "index_characters_on_season"
    t.index ["series"], name: "index_characters_on_series", using: :gin
  end

  create_table "charge_attacks", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "owner_id", null: false
    t.string "owner_type", null: false
    t.uuid "skill_id", null: false
    t.integer "uncap_level"
    t.uuid "alt_skill_id"
    t.text "alt_condition"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alt_skill_id"], name: "index_charge_attacks_on_alt_skill_id"
    t.index ["owner_type", "owner_id", "uncap_level"], name: "idx_on_owner_type_owner_id_uncap_level_b37b556440"
    t.index ["skill_id"], name: "index_charge_attacks_on_skill_id"
  end

  create_table "collection_artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "artifact_id", null: false
    t.integer "element", null: false
    t.integer "proficiency"
    t.integer "level", default: 1, null: false
    t.string "nickname"
    t.jsonb "skill1", default: {}, null: false
    t.jsonb "skill2", default: {}, null: false
    t.jsonb "skill3", default: {}, null: false
    t.jsonb "skill4", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reroll_slot"
    t.string "game_id"
    t.integer "attack_score"
    t.integer "defense_score"
    t.integer "special_score"
    t.integer "total_score"
    t.index ["artifact_id"], name: "index_collection_artifacts_on_artifact_id"
    t.index ["element"], name: "index_collection_artifacts_on_element"
    t.index ["user_id", "artifact_id"], name: "index_collection_artifacts_on_user_id_and_artifact_id"
    t.index ["user_id", "game_id"], name: "index_collection_artifacts_on_user_id_and_game_id", unique: true, where: "(game_id IS NOT NULL)"
    t.index ["user_id"], name: "index_collection_artifacts_on_user_id"
  end

  create_table "collection_characters", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "character_id", null: false
    t.integer "uncap_level", default: 0, null: false
    t.integer "transcendence_step", default: 0, null: false
    t.boolean "perpetuity", default: false, null: false
    t.uuid "awakening_id"
    t.integer "awakening_level", default: 1
    t.jsonb "ring1", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "ring2", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "ring3", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "ring4", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "earring", default: {"modifier" => nil, "strength" => nil}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["awakening_id"], name: "index_collection_characters_on_awakening_id"
    t.index ["character_id"], name: "index_collection_characters_on_character_id"
    t.index ["user_id", "character_id"], name: "index_collection_characters_on_user_id_and_character_id", unique: true
    t.index ["user_id"], name: "index_collection_characters_on_user_id"
  end

  create_table "collection_job_accessories", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "job_accessory_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_accessory_id"], name: "index_collection_job_accessories_on_job_accessory_id"
    t.index ["user_id", "job_accessory_id"], name: "idx_collection_job_acc_user_accessory", unique: true
    t.index ["user_id"], name: "index_collection_job_accessories_on_user_id"
  end

  create_table "collection_summons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "summon_id", null: false
    t.integer "uncap_level", default: 0, null: false
    t.integer "transcendence_step", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "game_id"
    t.index ["summon_id"], name: "index_collection_summons_on_summon_id"
    t.index ["user_id", "game_id"], name: "index_collection_summons_on_user_id_and_game_id", unique: true, where: "(game_id IS NOT NULL)"
    t.index ["user_id", "summon_id"], name: "index_collection_summons_on_user_id_and_summon_id"
    t.index ["user_id"], name: "index_collection_summons_on_user_id"
  end

  create_table "collection_weapons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.uuid "weapon_id", null: false
    t.integer "uncap_level", default: 0, null: false
    t.integer "transcendence_step", default: 0
    t.uuid "weapon_key1_id"
    t.uuid "weapon_key2_id"
    t.uuid "weapon_key3_id"
    t.uuid "weapon_key4_id"
    t.uuid "awakening_id"
    t.integer "awakening_level", default: 1, null: false
    t.float "ax_strength1"
    t.float "ax_strength2"
    t.integer "element"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "game_id"
    t.bigint "ax_modifier1_id"
    t.bigint "ax_modifier2_id"
    t.bigint "befoulment_modifier_id"
    t.float "befoulment_strength"
    t.integer "exorcism_level", default: 0
    t.index ["awakening_id"], name: "index_collection_weapons_on_awakening_id"
    t.index ["ax_modifier1_id"], name: "index_collection_weapons_on_ax_modifier1_id"
    t.index ["ax_modifier2_id"], name: "index_collection_weapons_on_ax_modifier2_id"
    t.index ["befoulment_modifier_id"], name: "index_collection_weapons_on_befoulment_modifier_id"
    t.index ["user_id", "game_id"], name: "index_collection_weapons_on_user_id_and_game_id", unique: true, where: "(game_id IS NOT NULL)"
    t.index ["user_id", "weapon_id"], name: "index_collection_weapons_on_user_id_and_weapon_id"
    t.index ["user_id"], name: "index_collection_weapons_on_user_id"
    t.index ["weapon_id"], name: "index_collection_weapons_on_weapon_id"
    t.index ["weapon_key1_id"], name: "index_collection_weapons_on_weapon_key1_id"
    t.index ["weapon_key2_id"], name: "index_collection_weapons_on_weapon_key2_id"
    t.index ["weapon_key3_id"], name: "index_collection_weapons_on_weapon_key3_id"
    t.index ["weapon_key4_id"], name: "index_collection_weapons_on_weapon_key4_id"
  end

  create_table "crew_gw_participations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "crew_id", null: false
    t.uuid "gw_event_id", null: false
    t.bigint "preliminary_ranking"
    t.bigint "final_ranking"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crew_id", "gw_event_id"], name: "index_crew_gw_participations_on_crew_id_and_gw_event_id", unique: true
    t.index ["crew_id"], name: "index_crew_gw_participations_on_crew_id"
    t.index ["gw_event_id"], name: "index_crew_gw_participations_on_gw_event_id"
  end

  create_table "crew_invitations", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "crew_id", null: false
    t.uuid "user_id", null: false, comment: "Invitee"
    t.uuid "invited_by_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "expires_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "phantom_player_id"
    t.index ["crew_id", "user_id", "status"], name: "index_crew_invitations_on_crew_id_and_user_id_and_status"
    t.index ["crew_id"], name: "index_crew_invitations_on_crew_id"
    t.index ["invited_by_id"], name: "index_crew_invitations_on_invited_by_id"
    t.index ["phantom_player_id"], name: "index_crew_invitations_on_phantom_player_id"
    t.index ["user_id", "status"], name: "index_crew_invitations_on_user_id_and_status"
    t.index ["user_id"], name: "index_crew_invitations_on_user_id"
  end

  create_table "crew_memberships", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "crew_id", null: false
    t.uuid "user_id", null: false
    t.integer "role", default: 0, null: false
    t.boolean "retired", default: false, null: false
    t.datetime "retired_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "joined_at"
    t.index ["crew_id", "role"], name: "index_crew_memberships_on_crew_id_and_role"
    t.index ["crew_id", "user_id"], name: "index_crew_memberships_on_crew_id_and_user_id", unique: true
    t.index ["crew_id"], name: "index_crew_memberships_on_crew_id"
    t.index ["user_id"], name: "index_crew_memberships_on_active_user", unique: true, where: "(retired = false)"
    t.index ["user_id"], name: "index_crew_memberships_on_user_id"
  end

  create_table "crews", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name", null: false
    t.string "gamertag"
    t.string "granblue_crew_id"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["granblue_crew_id"], name: "index_crews_on_granblue_crew_id", unique: true, where: "(granblue_crew_id IS NOT NULL)"
    t.index ["name"], name: "index_crews_on_name"
  end

  create_table "data_migrations", primary_key: "version", id: :string, force: :cascade do |t|
  end

  create_table "data_versions", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "filename", null: false
    t.datetime "imported_at", null: false
    t.index ["filename"], name: "index_data_versions_on_filename", unique: true
  end

  create_table "effects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp"
    t.text "description_en"
    t.text "description_jp"
    t.string "icon_path"
    t.integer "effect_type", null: false
    t.string "effect_class"
    t.uuid "effect_family_id"
    t.boolean "stackable", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effect_class"], name: "index_effects_on_effect_class"
    t.index ["name_en"], name: "index_effects_on_name_en"
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
    t.boolean "classic_ii", default: false
    t.boolean "collab", default: false
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

  create_table "grid_artifacts", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "grid_character_id", null: false
    t.uuid "artifact_id", null: false
    t.integer "element", null: false
    t.integer "proficiency"
    t.integer "level", default: 1, null: false
    t.jsonb "skill1", default: {}, null: false
    t.jsonb "skill2", default: {}, null: false
    t.jsonb "skill3", default: {}, null: false
    t.jsonb "skill4", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "reroll_slot"
    t.uuid "collection_artifact_id"
    t.boolean "orphaned", default: false, null: false
    t.index ["artifact_id"], name: "index_grid_artifacts_on_artifact_id"
    t.index ["collection_artifact_id"], name: "index_grid_artifacts_on_collection_artifact_id"
    t.index ["grid_character_id"], name: "index_grid_artifacts_on_grid_character_id", unique: true
    t.index ["orphaned"], name: "index_grid_artifacts_on_orphaned"
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
    t.jsonb "ring1", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "ring2", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "ring3", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "ring4", default: {"modifier" => nil, "strength" => nil}, null: false
    t.jsonb "earring", default: {"modifier" => nil, "strength" => nil}, null: false
    t.uuid "awakening_id"
    t.integer "awakening_level", default: 1
    t.uuid "collection_character_id"
    t.index ["awakening_id"], name: "index_grid_characters_on_awakening_id"
    t.index ["character_id"], name: "index_grid_characters_on_character_id"
    t.index ["collection_character_id"], name: "index_grid_characters_on_collection_character_id"
    t.index ["party_id", "position"], name: "index_grid_characters_on_party_id_and_position"
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
    t.uuid "collection_summon_id"
    t.boolean "orphaned", default: false, null: false
    t.index ["collection_summon_id"], name: "index_grid_summons_on_collection_summon_id"
    t.index ["orphaned"], name: "index_grid_summons_on_orphaned"
    t.index ["party_id", "position"], name: "index_grid_summons_on_party_id_and_position"
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
    t.float "ax_strength1"
    t.float "ax_strength2"
    t.integer "element"
    t.integer "awakening_level", default: 1, null: false
    t.uuid "awakening_id"
    t.integer "transcendence_step", default: 0
    t.string "weapon_key4_id"
    t.uuid "collection_weapon_id"
    t.boolean "orphaned", default: false, null: false
    t.bigint "ax_modifier1_id"
    t.bigint "ax_modifier2_id"
    t.bigint "befoulment_modifier_id"
    t.float "befoulment_strength"
    t.integer "exorcism_level", default: 0
    t.index ["awakening_id"], name: "index_grid_weapons_on_awakening_id"
    t.index ["ax_modifier1_id"], name: "index_grid_weapons_on_ax_modifier1_id"
    t.index ["ax_modifier2_id"], name: "index_grid_weapons_on_ax_modifier2_id"
    t.index ["befoulment_modifier_id"], name: "index_grid_weapons_on_befoulment_modifier_id"
    t.index ["collection_weapon_id"], name: "index_grid_weapons_on_collection_weapon_id"
    t.index ["orphaned"], name: "index_grid_weapons_on_orphaned"
    t.index ["party_id", "position"], name: "index_grid_weapons_on_party_id_and_position"
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

  create_table "gw_crew_scores", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "crew_gw_participation_id", null: false
    t.integer "round", null: false, comment: "0=prelims, 1=interlude, 2-5=finals day 1-4"
    t.bigint "crew_score", default: 0, null: false
    t.bigint "opponent_score"
    t.string "opponent_name"
    t.string "opponent_granblue_id"
    t.boolean "victory"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["crew_gw_participation_id", "round"], name: "index_gw_crew_scores_on_crew_gw_participation_id_and_round", unique: true
    t.index ["crew_gw_participation_id"], name: "index_gw_crew_scores_on_crew_gw_participation_id"
  end

  create_table "gw_events", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.integer "element", null: false
    t.date "start_date", null: false
    t.date "end_date", null: false
    t.integer "event_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_number"], name: "index_gw_events_on_event_number", unique: true
    t.index ["start_date"], name: "index_gw_events_on_start_date"
  end

  create_table "gw_individual_scores", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "crew_gw_participation_id", null: false
    t.uuid "crew_membership_id"
    t.integer "round", null: false
    t.bigint "score", default: 0, null: false
    t.boolean "is_cumulative", default: false, null: false
    t.uuid "recorded_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.uuid "phantom_player_id"
    t.boolean "excused", default: false, null: false
    t.text "excuse_reason"
    t.index ["crew_gw_participation_id", "crew_membership_id", "round"], name: "idx_gw_individual_scores_unique", unique: true
    t.index ["crew_gw_participation_id"], name: "index_gw_individual_scores_on_crew_gw_participation_id"
    t.index ["crew_membership_id"], name: "index_gw_individual_scores_on_crew_membership_id"
    t.index ["phantom_player_id"], name: "index_gw_individual_scores_on_phantom_player_id"
    t.index ["recorded_by_id"], name: "index_gw_individual_scores_on_recorded_by_id"
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
    t.string "image_id"
    t.integer "action_id"
    t.index ["action_id"], name: "index_job_skills_on_action_id"
    t.index ["image_id"], name: "index_job_skills_on_image_id"
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
    t.boolean "aux_weapon", default: false
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
    t.integer "preview_state", default: 0, null: false
    t.datetime "preview_generated_at"
    t.string "preview_s3_key"
    t.string "video_url", limit: 2048
    t.integer "summon_count"
    t.uuid "collection_source_user_id"
    t.string "boost_mod"
    t.string "boost_side"
    t.boolean "solo", default: false, null: false
    t.index ["accessory_id"], name: "index_parties_on_accessory_id"
    t.index ["boost_mod", "boost_side"], name: "index_parties_on_boost_mod_and_boost_side"
    t.index ["collection_source_user_id"], name: "index_parties_on_collection_source_user_id"
    t.index ["created_at"], name: "index_parties_on_created_at"
    t.index ["element"], name: "index_parties_on_element"
    t.index ["guidebook1_id"], name: "index_parties_on_guidebook1_id"
    t.index ["guidebook2_id"], name: "index_parties_on_guidebook2_id"
    t.index ["guidebook3_id"], name: "index_parties_on_guidebook3_id"
    t.index ["job_id"], name: "index_parties_on_job_id"
    t.index ["preview_generated_at"], name: "index_parties_on_preview_generated_at"
    t.index ["preview_state"], name: "index_parties_on_preview_state"
    t.index ["raid_id"], name: "index_parties_on_raid_id"
    t.index ["shortcode"], name: "index_parties_on_shortcode"
    t.index ["skill0_id"], name: "index_parties_on_skill0_id"
    t.index ["skill1_id"], name: "index_parties_on_skill1_id"
    t.index ["skill2_id"], name: "index_parties_on_skill2_id"
    t.index ["skill3_id"], name: "index_parties_on_skill3_id"
    t.index ["source_party_id"], name: "index_parties_on_source_party_id"
    t.index ["user_id"], name: "index_parties_on_user_id"
    t.index ["visibility", "created_at"], name: "index_parties_on_visibility_created_at"
    t.index ["weapons_count", "characters_count", "summons_count"], name: "index_parties_on_counters"
  end

  create_table "party_shares", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "party_id", null: false
    t.string "shareable_type", null: false
    t.uuid "shareable_id", null: false
    t.uuid "shared_by_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["party_id", "shareable_type", "shareable_id"], name: "index_party_shares_unique_per_shareable", unique: true
    t.index ["party_id"], name: "index_party_shares_on_party_id"
    t.index ["shareable_type", "shareable_id"], name: "index_party_shares_on_shareable"
    t.index ["shareable_type", "shareable_id"], name: "index_party_shares_on_shareable_type_and_shareable_id"
    t.index ["shared_by_id"], name: "index_party_shares_on_shared_by_id"
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

  create_table "pghero_query_stats", force: :cascade do |t|
    t.text "database"
    t.text "user"
    t.text "query"
    t.bigint "query_hash"
    t.float "total_time"
    t.bigint "calls"
    t.datetime "captured_at", precision: nil
    t.index ["database", "captured_at"], name: "index_pghero_query_stats_on_database_and_captured_at"
  end

  create_table "phantom_players", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "crew_id", null: false
    t.string "name", null: false
    t.string "granblue_id"
    t.text "notes"
    t.uuid "claimed_by_id"
    t.uuid "claimed_from_membership_id"
    t.boolean "claim_confirmed", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "retired", default: false, null: false
    t.datetime "retired_at"
    t.datetime "joined_at"
    t.datetime "deleted_at"
    t.index ["claimed_by_id"], name: "index_phantom_players_on_claimed_by_id"
    t.index ["claimed_from_membership_id"], name: "index_phantom_players_on_claimed_from_membership_id"
    t.index ["crew_id", "granblue_id"], name: "index_phantom_players_on_crew_id_and_granblue_id", unique: true, where: "(granblue_id IS NOT NULL)"
    t.index ["crew_id"], name: "index_phantom_players_on_crew_id"
    t.index ["deleted_at"], name: "index_phantom_players_on_deleted_at"
  end

  create_table "playlist_parties", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "playlist_id", null: false
    t.uuid "party_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["party_id"], name: "index_playlist_parties_on_party_id"
    t.index ["playlist_id", "party_id"], name: "index_playlist_parties_on_playlist_id_and_party_id", unique: true
    t.index ["playlist_id"], name: "index_playlist_parties_on_playlist_id"
  end

  create_table "playlists", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "title", null: false
    t.text "description"
    t.string "video_url"
    t.integer "visibility", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "slug", default: "", null: false
    t.index ["user_id", "slug"], name: "index_playlists_on_user_id_and_slug", unique: true
    t.index ["user_id", "title"], name: "index_playlists_on_user_id_and_title", unique: true
    t.index ["user_id"], name: "index_playlists_on_user_id"
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
    t.boolean "unlimited", default: false, null: false
  end

  create_table "raids", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.integer "level"
    t.integer "element"
    t.string "slug"
    t.uuid "group_id"
    t.integer "enemy_id"
    t.bigint "summon_id"
    t.bigint "quest_id"
    t.boolean "extra"
    t.integer "player_count", default: 18, null: false
  end

  create_table "skill_effects", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "skill_id", null: false
    t.uuid "effect_id", null: false
    t.integer "target_type"
    t.integer "duration_type"
    t.integer "duration_value"
    t.text "condition"
    t.integer "chance"
    t.decimal "value"
    t.decimal "cap"
    t.boolean "local", default: true
    t.boolean "permanent", default: false
    t.boolean "undispellable", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["effect_id"], name: "index_skill_effects_on_effect_id"
    t.index ["skill_id", "effect_id", "target_type"], name: "index_skill_effects_on_skill_id_and_effect_id_and_target_type"
    t.index ["skill_id"], name: "index_skill_effects_on_skill_id"
  end

  create_table "skill_values", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "skill_id", null: false
    t.integer "level", default: 1, null: false
    t.decimal "value"
    t.string "text_value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["skill_id", "level"], name: "index_skill_values_on_skill_id_and_level", unique: true
    t.index ["skill_id"], name: "index_skill_values_on_skill_id"
  end

  create_table "skills", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp"
    t.text "description_en"
    t.text "description_jp"
    t.integer "skill_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name_en"], name: "index_skills_on_name_en"
    t.index ["skill_type"], name: "index_skills_on_skill_type"
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

  create_table "summon_auras", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "summon_granblue_id", null: false
    t.text "description_en"
    t.text "description_jp"
    t.integer "aura_type"
    t.integer "boost_type"
    t.string "boost_target"
    t.decimal "boost_value"
    t.integer "uncap_level"
    t.text "condition"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["summon_granblue_id", "aura_type", "uncap_level"], name: "idx_on_summon_granblue_id_aura_type_uncap_level_631fc8f523"
    t.index ["summon_granblue_id"], name: "index_summon_auras_on_summon_granblue_id"
  end

  create_table "summon_calls", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "summon_granblue_id", null: false
    t.uuid "skill_id", null: false
    t.integer "cooldown"
    t.integer "uncap_level"
    t.uuid "alt_skill_id"
    t.text "alt_condition"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["alt_skill_id"], name: "index_summon_calls_on_alt_skill_id"
    t.index ["skill_id"], name: "index_summon_calls_on_skill_id"
    t.index ["summon_granblue_id", "uncap_level"], name: "index_summon_calls_on_summon_granblue_id_and_uncap_level"
    t.index ["summon_granblue_id"], name: "index_summon_calls_on_summon_granblue_id"
  end

  create_table "summon_series", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "slug", null: false
    t.integer "order", default: 0, null: false
    t.index ["order"], name: "index_summon_series_on_order"
    t.index ["slug"], name: "index_summon_series_on_slug", unique: true
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
    t.text "wiki_raw"
    t.jsonb "game_raw_en", comment: "JSON data from game (English)"
    t.jsonb "game_raw_jp", comment: "JSON data from game (Japanese)"
    t.integer "promotions", default: [], null: false, array: true
    t.uuid "summon_series_id"
    t.index ["granblue_id"], name: "index_summons_on_granblue_id"
    t.index ["name_en"], name: "index_summons_on_name_en", opclass: :gin_trgm_ops, using: :gin
    t.index ["promotions"], name: "index_summons_on_promotions", using: :gin
    t.index ["summon_series_id"], name: "index_summons_on_summon_series_id"
  end

  create_table "user_edit_keys", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "user_id", null: false
    t.string "edit_key", null: false
    t.string "shortcode", null: false
    t.datetime "created_at", null: false
    t.index ["user_id", "edit_key"], name: "index_user_edit_keys_on_user_id_and_edit_key", unique: true
    t.index ["user_id"], name: "index_user_edit_keys_on_user_id"
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
    t.integer "collection_privacy", default: 1, null: false
    t.boolean "show_gamertag", default: true, null: false
    t.boolean "show_granblue_id", default: false, null: false
    t.string "reset_password_token_digest"
    t.datetime "reset_password_sent_at"
    t.boolean "email_verified", default: false, null: false
    t.string "email_verification_token_digest"
    t.datetime "email_verification_sent_at"
    t.string "wiki_profile"
    t.boolean "show_wiki_profile", default: false, null: false
    t.index ["collection_privacy"], name: "index_users_on_collection_privacy"
  end

  create_table "weapon_awakenings", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "weapon_id", null: false
    t.uuid "awakening_id", null: false
    t.index ["awakening_id"], name: "index_weapon_awakenings_on_awakening_id"
    t.index ["weapon_id"], name: "index_weapon_awakenings_on_weapon_id"
  end

  create_table "weapon_key_series", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.uuid "weapon_key_id", null: false
    t.uuid "weapon_series_id", null: false
    t.index ["weapon_key_id", "weapon_series_id"], name: "index_weapon_key_series_on_weapon_key_id_and_weapon_series_id", unique: true
    t.index ["weapon_key_id"], name: "index_weapon_key_series_on_weapon_key_id"
    t.index ["weapon_series_id"], name: "index_weapon_key_series_on_weapon_series_id"
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

  create_table "weapon_series", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en", null: false
    t.string "name_jp", null: false
    t.string "slug", null: false
    t.integer "order", default: 0, null: false
    t.boolean "extra", default: false, null: false
    t.boolean "element_changeable", default: false, null: false
    t.boolean "has_weapon_keys", default: false, null: false
    t.boolean "has_awakening", default: false, null: false
    t.integer "augment_type", default: 0, null: false
    t.integer "num_weapon_keys"
    t.index ["order"], name: "index_weapon_series_on_order"
    t.index ["slug"], name: "index_weapon_series_on_slug", unique: true
  end

  create_table "weapon_skill_boost_types", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "key", null: false
    t.string "name_en", null: false
    t.string "name_jp"
    t.string "category", null: false
    t.decimal "grid_cap", precision: 12, scale: 2
    t.boolean "cap_is_flat", default: false, null: false
    t.string "stacking_rule", default: "additive", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_weapon_skill_boost_types_on_category"
    t.index ["key"], name: "index_weapon_skill_boost_types_on_key", unique: true
  end

  create_table "weapon_skill_data", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "modifier", null: false
    t.string "boost_type", null: false
    t.string "series"
    t.string "size", null: false
    t.string "formula_type", default: "flat", null: false
    t.decimal "sl1", precision: 10, scale: 4
    t.decimal "sl10", precision: 10, scale: 4
    t.decimal "sl15", precision: 10, scale: 4
    t.decimal "sl20", precision: 10, scale: 4
    t.decimal "sl25", precision: 10, scale: 4
    t.decimal "coefficient", precision: 10, scale: 4
    t.boolean "aura_boostable", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["modifier", "boost_type", "series", "size"], name: "index_weapon_skill_data_uniqueness", unique: true
    t.index ["modifier"], name: "index_weapon_skill_data_on_modifier"
    t.index ["series"], name: "index_weapon_skill_data_on_series"
  end

  create_table "weapon_skills", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "weapon_granblue_id", null: false
    t.uuid "skill_id", null: false
    t.integer "position", null: false
    t.string "skill_modifier"
    t.string "skill_series"
    t.string "skill_size"
    t.integer "unlock_level"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "uncap_level", default: 0, null: false
    t.index ["skill_id"], name: "index_weapon_skills_on_skill_id"
    t.index ["skill_series"], name: "index_weapon_skills_on_skill_series"
    t.index ["weapon_granblue_id", "position", "uncap_level"], name: "index_weapon_skills_on_weapon_position_uncap", unique: true
    t.index ["weapon_granblue_id"], name: "index_weapon_skills_on_weapon_granblue_id"
  end

  create_table "weapon_stat_modifiers", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name_en", null: false
    t.string "name_jp"
    t.string "category", null: false
    t.string "stat"
    t.integer "polarity", default: 1, null: false
    t.string "suffix"
    t.float "base_min"
    t.float "base_max"
    t.integer "game_skill_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_weapon_stat_modifiers_on_category"
    t.index ["game_skill_id"], name: "index_weapon_stat_modifiers_on_game_skill_id", unique: true
    t.index ["slug"], name: "index_weapon_stat_modifiers_on_slug", unique: true
  end

  create_table "weapons", id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
    t.string "name_en"
    t.string "name_jp"
    t.string "granblue_id"
    t.integer "rarity"
    t.integer "element"
    t.integer "proficiency"
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
    t.string "recruits"
    t.integer "new_series"
    t.text "wiki_raw"
    t.jsonb "game_raw_en", comment: "JSON data from game (English)"
    t.jsonb "game_raw_jp", comment: "JSON data from game (Japanese)"
    t.integer "promotions", default: [], null: false, array: true
    t.uuid "weapon_series_id"
    t.boolean "gacha", default: false, null: false
    t.integer "extra_prerequisite"
    t.string "forged_from"
    t.uuid "forge_chain_id"
    t.integer "forge_order"
    t.integer "max_exorcism_level"
    t.index ["forge_chain_id"], name: "index_weapons_on_forge_chain_id"
    t.index ["forged_from"], name: "index_weapons_on_forged_from"
    t.index ["gacha"], name: "index_weapons_on_gacha"
    t.index ["granblue_id"], name: "index_weapons_on_granblue_id"
    t.index ["name_en"], name: "index_weapons_on_name_en", opclass: :gin_trgm_ops, using: :gin
    t.index ["promotions"], name: "index_weapons_on_promotions", using: :gin
    t.index ["recruits"], name: "index_weapons_on_recruits"
    t.index ["weapon_series_id"], name: "index_weapons_on_weapon_series_id"
  end

  add_foreign_key "character_series_memberships", "character_series"
  add_foreign_key "character_series_memberships", "characters"
  add_foreign_key "character_skills", "skills"
  add_foreign_key "character_skills", "skills", column: "alt_skill_id"
  add_foreign_key "charge_attacks", "skills"
  add_foreign_key "charge_attacks", "skills", column: "alt_skill_id"
  add_foreign_key "collection_artifacts", "artifacts"
  add_foreign_key "collection_artifacts", "users"
  add_foreign_key "collection_characters", "awakenings"
  add_foreign_key "collection_characters", "characters"
  add_foreign_key "collection_characters", "users"
  add_foreign_key "collection_job_accessories", "job_accessories"
  add_foreign_key "collection_job_accessories", "users"
  add_foreign_key "collection_summons", "summons"
  add_foreign_key "collection_summons", "users"
  add_foreign_key "collection_weapons", "awakenings"
  add_foreign_key "collection_weapons", "users"
  add_foreign_key "collection_weapons", "weapon_keys", column: "weapon_key1_id"
  add_foreign_key "collection_weapons", "weapon_keys", column: "weapon_key2_id"
  add_foreign_key "collection_weapons", "weapon_keys", column: "weapon_key3_id"
  add_foreign_key "collection_weapons", "weapon_keys", column: "weapon_key4_id"
  add_foreign_key "collection_weapons", "weapon_stat_modifiers", column: "ax_modifier1_id"
  add_foreign_key "collection_weapons", "weapon_stat_modifiers", column: "ax_modifier2_id"
  add_foreign_key "collection_weapons", "weapon_stat_modifiers", column: "befoulment_modifier_id"
  add_foreign_key "collection_weapons", "weapons"
  add_foreign_key "crew_gw_participations", "crews"
  add_foreign_key "crew_gw_participations", "gw_events"
  add_foreign_key "crew_invitations", "crews"
  add_foreign_key "crew_invitations", "phantom_players"
  add_foreign_key "crew_invitations", "users"
  add_foreign_key "crew_invitations", "users", column: "invited_by_id"
  add_foreign_key "crew_memberships", "crews"
  add_foreign_key "crew_memberships", "users"
  add_foreign_key "effects", "effects", column: "effect_family_id"
  add_foreign_key "favorites", "parties"
  add_foreign_key "favorites", "users"
  add_foreign_key "grid_artifacts", "artifacts"
  add_foreign_key "grid_artifacts", "collection_artifacts"
  add_foreign_key "grid_artifacts", "grid_characters"
  add_foreign_key "grid_characters", "awakenings"
  add_foreign_key "grid_characters", "characters"
  add_foreign_key "grid_characters", "collection_characters"
  add_foreign_key "grid_characters", "parties"
  add_foreign_key "grid_summons", "collection_summons"
  add_foreign_key "grid_summons", "parties"
  add_foreign_key "grid_summons", "summons"
  add_foreign_key "grid_weapons", "awakenings"
  add_foreign_key "grid_weapons", "collection_weapons"
  add_foreign_key "grid_weapons", "parties"
  add_foreign_key "grid_weapons", "weapon_keys", column: "weapon_key3_id"
  add_foreign_key "grid_weapons", "weapon_stat_modifiers", column: "ax_modifier1_id"
  add_foreign_key "grid_weapons", "weapon_stat_modifiers", column: "ax_modifier2_id"
  add_foreign_key "grid_weapons", "weapon_stat_modifiers", column: "befoulment_modifier_id"
  add_foreign_key "grid_weapons", "weapons"
  add_foreign_key "gw_crew_scores", "crew_gw_participations"
  add_foreign_key "gw_individual_scores", "crew_gw_participations"
  add_foreign_key "gw_individual_scores", "crew_memberships"
  add_foreign_key "gw_individual_scores", "phantom_players"
  add_foreign_key "gw_individual_scores", "users", column: "recorded_by_id"
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
  add_foreign_key "parties", "parties", column: "source_party_id"
  add_foreign_key "parties", "raids"
  add_foreign_key "parties", "users"
  add_foreign_key "parties", "users", column: "collection_source_user_id"
  add_foreign_key "party_shares", "parties"
  add_foreign_key "party_shares", "users", column: "shared_by_id"
  add_foreign_key "phantom_players", "crew_memberships", column: "claimed_from_membership_id"
  add_foreign_key "phantom_players", "crews"
  add_foreign_key "phantom_players", "users", column: "claimed_by_id"
  add_foreign_key "playlist_parties", "parties"
  add_foreign_key "playlist_parties", "playlists"
  add_foreign_key "playlists", "users"
  add_foreign_key "raids", "raid_groups", column: "group_id", name: "raids_group_id_fkey"
  add_foreign_key "skill_effects", "effects", name: "fk_skill_effects_effects"
  add_foreign_key "skill_effects", "skills", name: "fk_skill_effects_skills"
  add_foreign_key "skill_values", "skills"
  add_foreign_key "summon_calls", "skills"
  add_foreign_key "summon_calls", "skills", column: "alt_skill_id"
  add_foreign_key "summons", "summon_series"
  add_foreign_key "user_edit_keys", "users"
  add_foreign_key "weapon_awakenings", "awakenings"
  add_foreign_key "weapon_awakenings", "weapons"
  add_foreign_key "weapon_key_series", "weapon_keys"
  add_foreign_key "weapon_key_series", "weapon_series"
  add_foreign_key "weapon_skills", "skills"
  add_foreign_key "weapons", "weapon_series"
end

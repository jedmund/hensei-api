# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only character list for the database editor's grid (GBF-138), and
      # its schema: what the editor may filter, sort, show and write (GBF-143).
      # The public team-builder search stays at /search/characters.
      class CharactersController < Api::V1::ApiController
        include AdminCollection

        SKILL_EXISTS = 'EXISTS (SELECT 1 FROM character_skills ' \
                       'WHERE character_skills.character_id = characters.id)'

        before_action :ensure_editor_role

        admin_collection Character do
          search :name_en, :name_jp, :granblue_id

          filter :element, type: :integer, facet: true
          filter :rarity, type: :integer, facet: true
          filter :season, type: :integer, facet: true
          filter :gender, type: :integer
          filter :proficiency, type: :integer, column: %i[proficiency1 proficiency2], facet: true
          # Membership is many-to-many; the legacy characters.series array is not used.
          reference_filter :series, references: CharacterSeries, through: :character_series_memberships,
                                    column: :character_series_id, facet: true
          filter :release_date, type: :date
          filter :flb_date, type: :date
          filter :ulb_date, type: :date
          filter :transcendence_date, type: :date
          filter :latest_date, type: :date
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime
          filter :special, type: :boolean
          filter :style_swap, type: :boolean
          filter :flb, type: :boolean
          filter :ulb, type: :boolean
          filter :transcendence, type: :boolean

          flag :missing_name_jp, "characters.name_jp IS NULL OR characters.name_jp = ''"
          flag :no_skills, "NOT #{SKILL_EXISTS}"

          sort :name_en, :name_jp, :granblue_id, :rarity, :element, :season,
               :release_date, :flb_date, :ulb_date, :transcendence_date, :latest_date,
               :updated_at, :created_at
          default_sort '-latest_date', 'name_en'

          %i[granblue_id name_en name_jp element rarity proficiency1 proficiency2 gender race1 race2
             season special style_swap style_name_en style_name_jp
             flb ulb transcendence max_transcendence_stage
             release_date flb_date ulb_date transcendence_date latest_date
             min_hp max_hp max_hp_flb max_hp_ulb max_hp_transcendence
             min_atk max_atk max_atk_flb max_atk_ulb max_atk_transcendence
             base_da base_ta ougi_ratio ougi_ratio_flb
             wiki_en wiki_ja gamewith kamigame nicknames_en nicknames_jp created_at updated_at].each { |name| field name }

          field :series, includes: :character_series_records, value: lambda { |c|
            c.character_series_records.sort_by(&:order).map { |s| s.slice(:id, :slug, :name_en, :name_jp) }
          }
          field :skill_count, select: 'SELECT COUNT(*) FROM character_skills ' \
                                      'WHERE character_skills.character_id = characters.id'

          default_fields :granblue_id, :name_en, :name_jp, :element, :rarity, :proficiency1, :proficiency2,
                         :style_swap, :release_date, :latest_date, :updated_at

          etag_sources :character_skills, :character_series_memberships, CharacterSeries

          writable Api::V1::CharactersController::PERMITTED
          enums element: Character::ELEMENT_VALUES, rarity: Character::RARITY_VALUES,
                gender: Character::GENDER_VALUES, season: GranblueEnums::CHARACTER_SEASONS,
                proficiency: Character::PROFICIENCY_VALUES,
                proficiency1: Character::PROFICIENCY_VALUES,
                proficiency2: Character::SECOND_PROFICIENCY_VALUES,
                race1: Character::RACE_VALUES, race2: Character::RACE_VALUES
        end

        def index
          render_admin_collection
        end

        def schema
          render_admin_schema
        end
      end
    end
  end
end

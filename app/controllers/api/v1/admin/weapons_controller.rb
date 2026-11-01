# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only weapon list for the database editor's grid (GBF-138).
      # The public team-builder search stays at /search/weapons.
      class WeaponsController < Api::V1::ApiController
        include AdminCollection

        SKILL_EXISTS = 'EXISTS (SELECT 1 FROM weapon_skills ' \
                       'WHERE weapon_skills.weapon_granblue_id = weapons.granblue_id)'

        before_action :ensure_editor_role

        admin_collection Weapon do
          search :name_en, :name_jp, :granblue_id

          filter :element, type: :integer, facet: true
          filter :rarity, type: :integer, facet: true
          filter :proficiency, type: :integer, facet: true
          reference_filter :series, references: WeaponSeries, column: :weapon_series_id, facet: true
          filter :granblue_id, type: :string
          filter :release_date, type: :date
          filter :flb_date, type: :date
          filter :ulb_date, type: :date
          filter :transcendence_date, type: :date
          filter :latest_date, type: :date
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime
          filter :flb, type: :boolean
          filter :ulb, type: :boolean
          filter :transcendence, type: :boolean
          filter :extra, type: :boolean
          filter :limit, type: :boolean

          flag :missing_name_jp, "weapons.name_jp IS NULL OR weapons.name_jp = ''"
          flag :no_skills, "NOT #{SKILL_EXISTS}"

          # latest_date is the stored GREATEST of the release and uncap dates:
          # the last time the game changed the weapon. updated_at is the last site edit.
          sort :name_en, :name_jp, :granblue_id, :rarity, :element, :proficiency,
               :release_date, :flb_date, :ulb_date, :transcendence_date, :latest_date,
               :updated_at, :created_at
          default_sort '-latest_date', 'name_en'

          %i[granblue_id name_en name_jp element rarity proficiency
             release_date flb_date ulb_date transcendence_date latest_date
             flb ulb transcendence extra limit
             max_level max_skill_level max_awakening_level max_exorcism_level
             min_hp max_hp max_hp_flb max_hp_ulb min_atk max_atk max_atk_flb max_atk_ulb
             promotions nicknames_en nicknames_jp recruits forged_from weapon_series_variant_id
             wiki_en wiki_ja gamewith kamigame created_at updated_at].each { |name| field name }

          field :series_id, column: :weapon_series_id
          field :series_slug, includes: :weapon_series, value: ->(w) { w.weapon_series&.slug }
          field :series_name_en, includes: :weapon_series, value: ->(w) { w.weapon_series&.name_en }
          field :series_name_jp, includes: :weapon_series, value: ->(w) { w.weapon_series&.name_jp }
          field :skill_count, select: 'SELECT COUNT(*) FROM weapon_skills ' \
                                      'WHERE weapon_skills.weapon_granblue_id = weapons.granblue_id'

          default_fields :granblue_id, :name_en, :name_jp, :element, :rarity, :proficiency,
                         :series_id, :series_slug, :release_date, :updated_at

          etag_sources :weapon_skills, :weapon_series
        end

        def index
          render_admin_collection
        end
      end
    end
  end
end

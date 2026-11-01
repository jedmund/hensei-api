# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only summon list for the database editor's grid (GBF-138), and
      # its schema: what the editor may filter, sort, show and write (GBF-143).
      # The public team-builder search stays at /search/summons.
      class SummonsController < Api::V1::ApiController
        include AdminCollection

        AURA_EXISTS = 'EXISTS (SELECT 1 FROM summon_auras ' \
                      'WHERE summon_auras.summon_granblue_id = summons.granblue_id)'

        # Standard max level by rarity and uncaps, as for weapons: R 50; SR 75, FLB 150;
        # SSR 100, FLB 150, ULB 200, transcended 250. The flag lists the summons that
        # differ for review. IS DISTINCT FROM keeps it true or false, never NULL.
        CAPS_MISMATCH = <<~SQL.squish
          summons.max_level IS DISTINCT FROM (
            CASE
              WHEN summons.rarity = 1 THEN 50
              WHEN summons.rarity = 2 AND summons.flb THEN 150
              WHEN summons.rarity = 2 THEN 75
              WHEN summons.rarity = 3 AND summons.transcendence THEN 250
              WHEN summons.rarity = 3 AND summons.ulb THEN 200
              WHEN summons.rarity = 3 AND summons.flb THEN 150
              WHEN summons.rarity = 3 THEN 100
            END
          )
        SQL

        before_action :ensure_editor_role

        admin_collection Summon do
          search :name_en, :name_jp, :granblue_id

          filter :element, type: :integer, facet: true
          filter :rarity, type: :integer, facet: true
          # summons.series is a legacy string column; the series is summon_series_id.
          reference_filter :series, references: SummonSeries, column: :summon_series_id, facet: true
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
          filter :subaura, type: :boolean
          filter :limit, type: :boolean
          filter :support_eligible, type: :boolean

          flag :missing_name_jp, "summons.name_jp IS NULL OR summons.name_jp = ''"
          flag :no_auras, "NOT #{AURA_EXISTS}"
          flag :caps_mismatch, CAPS_MISMATCH

          sort :name_en, :name_jp, :granblue_id, :rarity, :element, :max_level,
               :release_date, :flb_date, :ulb_date, :transcendence_date, :latest_date,
               :updated_at, :created_at
          default_sort '-latest_date', 'name_en'

          %i[granblue_id name_en name_jp element rarity flb ulb transcendence subaura limit support_eligible max_level
             release_date flb_date ulb_date transcendence_date latest_date
             min_hp max_hp max_hp_flb max_hp_ulb max_hp_xlb min_atk max_atk max_atk_flb max_atk_ulb max_atk_xlb
             promotions wiki_en wiki_ja gamewith kamigame nicknames_en nicknames_jp created_at updated_at].each { |name| field name }

          field :series_id, column: :summon_series_id
          field :series_slug, includes: :summon_series, value: ->(s) { s.summon_series&.slug }
          field :series_name_en, includes: :summon_series, value: ->(s) { s.summon_series&.name_en }
          field :series_name_jp, includes: :summon_series, value: ->(s) { s.summon_series&.name_jp }
          field :aura_count, select: 'SELECT COUNT(*) FROM summon_auras ' \
                                     'WHERE summon_auras.summon_granblue_id = summons.granblue_id'

          default_fields :granblue_id, :name_en, :name_jp, :element, :rarity, :series_id, :series_slug,
                         :release_date, :latest_date, :updated_at

          etag_sources :summon_series, :auras

          writable Api::V1::SummonsController::PERMITTED
          enums element: Summon::ELEMENT_VALUES, rarity: Summon::RARITY_VALUES,
                promotions: GranblueEnums::PROMOTIONS
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

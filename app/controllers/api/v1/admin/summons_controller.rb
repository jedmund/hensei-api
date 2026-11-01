# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only summon list for the database editor's grid (GBF-138).
      # The public team-builder search stays at /search/summons.
      class SummonsController < Api::V1::ApiController
        include AdminCollection

        AURA_EXISTS = 'EXISTS (SELECT 1 FROM summon_auras ' \
                      'WHERE summon_auras.summon_granblue_id = summons.granblue_id)'

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
        end

        def index
          render_admin_collection
        end
      end
    end
  end
end

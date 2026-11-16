# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only summon series list for the database editor, and its schema.
      class SummonSeriesController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection SummonSeries do
          search :name_en, :name_jp, :slug

          filter :updated_at, type: :datetime

          sort :order, :name_en, :name_jp, :slug, :updated_at, :created_at
          default_sort 'order', 'name_en'

          %i[slug name_en name_jp order created_at updated_at].each { |name| field name }
          field :summon_count, select: 'SELECT COUNT(*) FROM summons WHERE summons.summon_series_id = summon_series.id'

          default_fields :slug, :name_en, :name_jp, :order

          etag_sources :summons

          writable Api::V1::SummonSeriesController::PERMITTED
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

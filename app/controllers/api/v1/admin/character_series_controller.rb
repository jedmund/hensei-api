# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only character series list for the database editor, and its
      # schema (GBF-143).
      class CharacterSeriesController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection CharacterSeries do
          search :name_en, :name_jp, :slug

          filter :updated_at, type: :datetime

          sort :order, :name_en, :name_jp, :slug, :updated_at, :created_at
          default_sort 'order', 'name_en'

          %i[slug name_en name_jp order created_at updated_at].each { |name| field name }
          field :character_count, select: 'SELECT COUNT(*) FROM character_series_memberships ' \
                                          'WHERE character_series_memberships.character_series_id = character_series.id'

          default_fields :slug, :name_en, :name_jp, :order

          etag_sources :character_series_memberships

          writable Api::V1::CharacterSeriesController::PERMITTED
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

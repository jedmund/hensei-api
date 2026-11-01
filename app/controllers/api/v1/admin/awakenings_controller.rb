# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only awakening list (weapon and character awakenings) for the
      # database editor, and its schema (GBF-143).
      class AwakeningsController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection Awakening do
          search :name_en, :name_jp, :slug

          filter :object_type, type: :string, facet: true
          filter :updated_at, type: :datetime

          sort :object_type, :order, :name_en, :name_jp, :slug, :updated_at, :created_at
          default_sort 'object_type', 'order'

          %i[slug name_en name_jp object_type order created_at updated_at].each { |name| field name }

          default_fields :slug, :name_en, :name_jp, :object_type, :order, :updated_at

          writable Api::V1::AwakeningsController::PERMITTED
          enums object_type: Awakening::OBJECT_TYPES.index_by(&:itself)
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

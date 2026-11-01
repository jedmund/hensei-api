# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only weapon series list for the database editor, and its schema
      # (GBF-143). Variants are written through weapon_series_variants.
      class WeaponSeriesController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection WeaponSeries do
          search :name_en, :name_jp, :slug

          filter :augment_type, type: :string, facet: true
          filter :extra, type: :boolean
          filter :element_changeable, type: :boolean
          filter :has_weapon_keys, type: :boolean
          filter :has_awakening, type: :boolean
          filter :updated_at, type: :datetime

          sort :order, :name_en, :name_jp, :slug, :updated_at, :created_at
          default_sort 'order', 'name_en'

          %i[slug name_en name_jp order extra element_changeable has_weapon_keys has_awakening
             augment_type num_weapon_keys created_at updated_at].each { |name| field name }
          field :weapon_count, select: 'SELECT COUNT(*) FROM weapons WHERE weapons.weapon_series_id = weapon_series.id'

          default_fields :slug, :name_en, :name_jp, :order

          etag_sources :weapons, :weapon_series_variants

          writable Api::V1::WeaponSeriesController::PERMITTED
          enums augment_type: WeaponSeries.augment_types
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

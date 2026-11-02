# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only bullet list for the database editor, and its schema: what
      # the editor may filter, sort, show and write (GBF-143).
      class BulletsController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection Bullet do
          search :name_en, :name_jp, :slug, :granblue_id

          filter :bullet_type, type: :integer, facet: true
          filter :hits_all, type: :boolean
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime

          sort :name_en, :name_jp, :granblue_id, :slug, :bullet_type, :atk, :order, :updated_at, :created_at
          default_sort 'bullet_type', 'order'

          %i[granblue_id name_en name_jp slug bullet_type atk hits_all order effect_en effect_jp
             created_at updated_at].each { |name| field name }

          default_fields :granblue_id, :name_en, :name_jp, :slug, :bullet_type, :atk, :hits_all, :order,
                         :effect_en, :effect_jp, :updated_at

          writable Api::V1::BulletsController::PERMITTED
          enums bullet_type: Bullet::BULLET_TYPES
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

# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only character role list for the database editor, and its
      # schema (GBF-143). Roles are a short hand-ordered list: the editor shows
      # them all in sort_order and reorders them through
      # POST /grid_character_roles/reorder.
      class CharacterRolesController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection GridCharacterRole do
          search :name_en, :name_jp

          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime

          sort :sort_order, :name_en, :name_jp, :created_at, :updated_at
          default_sort 'sort_order', 'name_en'

          %i[name_en name_jp sort_order created_at updated_at].each { |name| field name }
          # Versioned like the public role JSON, so a re-uploaded icon shows
          field :icon_key, value: :versioned_icon_key.to_proc

          default_fields :name_en, :name_jp, :sort_order, :icon_key

          writable Api::V1::GridCharacterRolesController::PERMITTED
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

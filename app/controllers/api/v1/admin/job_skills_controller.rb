# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only job skill list for the database editor, and its schema:
      # what the editor may filter, sort, show and write (GBF-143).
      class JobSkillsController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection JobSkill do
          search :name_en, :name_jp, :slug

          filter :job, type: :uuid, column: :job_id, facet: true
          filter :color, type: :integer, facet: true
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime
          filter :main, type: :boolean
          filter :sub, type: :boolean
          filter :emp, type: :boolean
          filter :base, type: :boolean

          sort :name_en, :name_jp, :slug, :color, :order, :updated_at, :created_at
          default_sort 'name_en'

          %i[name_en name_jp slug color main sub emp base order image_id action_id job_id
             created_at updated_at].each { |name| field name }

          field :job, includes: :job, value: ->(s) { s.job&.slice(:id, :granblue_id, :name_en, :name_jp) }

          default_fields :name_en, :name_jp, :slug, :color, :main, :sub, :emp, :base, :order, :job, :updated_at

          etag_sources :job

          writable Api::V1::JobSkillsController::PERMITTED
          enums color: JobSkill::COLORS
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

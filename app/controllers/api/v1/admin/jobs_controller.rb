# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only job list for the database editor, and its schema: what the
      # editor may filter, sort, show and write (GBF-143).
      class JobsController < Api::V1::ApiController
        include AdminCollection

        SKILL_EXISTS = 'EXISTS (SELECT 1 FROM job_skills WHERE job_skills.job_id = jobs.id)'

        before_action :ensure_editor_role

        admin_collection Job do
          search :name_en, :name_jp, :granblue_id

          filter :row, type: :string, facet: true
          filter :proficiency, type: :integer, column: %i[proficiency1 proficiency2], facet: true
          filter :accessory_type, type: :integer, facet: true
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime
          filter :master_level, type: :boolean
          filter :ultimate_mastery, type: :boolean
          filter :aux_weapon, type: :boolean
          filter :accessory, type: :boolean

          flag :no_skills, "NOT #{SKILL_EXISTS}"

          sort :name_en, :name_jp, :granblue_id, :row, :order, :updated_at, :created_at
          default_sort 'row', 'order'

          %i[granblue_id name_en name_jp row order proficiency1 proficiency2
             master_level ultimate_mastery aux_weapon accessory accessory_type base_job_id
             created_at updated_at].each { |name| field name }

          field :skill_count, select: 'SELECT COUNT(*) FROM job_skills WHERE job_skills.job_id = jobs.id'

          default_fields :granblue_id, :name_en, :name_jp, :row, :order, :proficiency1, :proficiency2, :updated_at

          etag_sources :skills

          writable Api::V1::JobsController::PERMITTED
          enums row: Job::ROWS, proficiency: Job::PROFICIENCY_VALUES,
                proficiency1: Job::PROFICIENCY_VALUES, proficiency2: Job::PROFICIENCY_VALUES,
                accessory_type: Job::ACCESSORY_TYPES
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

# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only job accessory list for the database editor, and its schema:
      # what the editor may filter, sort, show and write (GBF-143).
      class JobAccessoriesController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection JobAccessory do
          search :name_en, :name_jp, :granblue_id

          filter :accessory_type, type: :integer, facet: true
          filter :rarity, type: :integer, facet: true
          filter :job, type: :uuid, column: :job_id, facet: true
          filter :release_date, type: :date
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime

          sort :name_en, :name_jp, :granblue_id, :rarity, :accessory_type, :release_date, :updated_at, :created_at
          default_sort 'accessory_type', 'granblue_id'

          %i[granblue_id name_en name_jp accessory_type rarity release_date job_id
             created_at updated_at].each { |name| field name }

          field :job, includes: :job, value: ->(a) { a.job&.slice(:id, :granblue_id, :name_en, :name_jp) }

          default_fields :granblue_id, :name_en, :name_jp, :accessory_type, :rarity, :job, :release_date, :updated_at

          etag_sources :job

          writable Api::V1::JobAccessoriesController::PERMITTED
          enums accessory_type: JobAccessory::ACCESSORY_TYPES, rarity: JobAccessory::RARITY_VALUES
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

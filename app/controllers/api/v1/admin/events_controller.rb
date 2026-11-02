# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Event list for the database editor, and its schema (GBF-143). Curators
      # read it too: they pick staff teams for events. Only editors write
      # (EventsController).
      class EventsController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_curator_role

        admin_collection Event do
          search :name_en, :name_jp

          filter :kind, type: :string, facet: true
          filter :series, type: :string, facet: true
          filter :status, type: :string, facet: true
          # The boss's element, as its integer like everywhere else in the API
          filter :element, type: :integer, facet: true
          filter :event_number, type: :integer
          filter :starts_at, type: :datetime
          filter :ends_at, type: :datetime
          filter :created_at, type: :datetime
          filter :updated_at, type: :datetime

          sort :name_en, :name_jp, :kind, :event_number, :starts_at, :ends_at, :updated_at, :created_at
          default_sort '-starts_at'

          %i[name_en name_jp kind series status event_number starts_at ends_at image_key
             created_at updated_at].each { |name| field name }
          field :element, value: ->(event) { event.element_value }
          field :second_element, value: ->(event) { event.second_element_value }
          field :raid_count, select: 'SELECT COUNT(*) FROM event_raids WHERE event_raids.event_id = events.id'

          default_fields :name_en, :name_jp, :kind, :element, :event_number, :starts_at, :ends_at, :raid_count

          etag_sources :event_raids

          writable Api::V1::EventsController::PERMITTED
          enums kind: Event.kinds, series: Event::SERIES.index_by(&:itself), status: Event.statuses,
                element: GranblueEnums::ELEMENTS, second_element: GranblueEnums::ELEMENTS
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

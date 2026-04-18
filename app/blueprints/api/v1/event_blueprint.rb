# frozen_string_literal: true

module Api
  module V1
    class EventBlueprint < ApiBlueprint
      fields :name, :event_type, :start_time, :end_time, :element, :banner_image, :created_at, :updated_at

      field :status do |event|
        event.status
      end
    end
  end
end

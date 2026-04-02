# frozen_string_literal: true

module Api
  module V1
    class EventBlueprint < ApiBlueprint
      fields :name, :slug, :event_type, :start_time, :end_time, :element, :created_at, :updated_at

      field :banner_image do |event|
        event.banner_image_path
      end

      field :status do |event|
        event.status
      end
    end
  end
end

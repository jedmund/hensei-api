# frozen_string_literal: true

module Api
  module V1
    # Callers preload `event_raids: { raid: :group }`. Pass `editor: true` to
    # include the sync bookkeeping fields.
    class EventBlueprint < ApiBlueprint
      field :name do |event|
        { en: event.name_en, ja: event.name_jp }
      end

      fields :kind, :starts_at, :ends_at, :status

      # The boss's element, as an integer from GranblueEnums::ELEMENTS (like
      # parties.element).
      field :element do |event|
        event.element_value
      end

      # The element teams bring against that boss (integer), or null.
      field :advantage_element do |event|
        event.advantage_element
      end

      # Host-relative, like StickerBlueprint.
      field :image_url do |event|
        next nil if event.image_key.blank?

        "#{event.image_key}?v=#{event.updated_at.to_i}"
      end

      field :raids do |event|
        RaidBlueprint.render_as_hash(event.event_raids.map(&:raid), view: :list)
      end

      field :event_number, if: ->(_field, _event, options) { options[:editor] }
      field :source_refs, if: ->(_field, _event, options) { options[:editor] }
      field :source_payload, if: ->(_field, _event, options) { options[:editor] }
    end
  end
end

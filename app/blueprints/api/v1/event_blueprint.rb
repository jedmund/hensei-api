# frozen_string_literal: true

module Api
  module V1
    # Callers preload `event_raids: { raid: :group }`. Pass `editor: true` to
    # include the sync bookkeeping fields.
    class EventBlueprint < ApiBlueprint
      field :name do |event|
        { en: event.name_en, ja: event.name_jp }
      end

      fields :kind, :series, :starts_at, :ends_at, :status

      # The boss's element, as an integer from GranblueEnums::ELEMENTS (like
      # parties.element).
      field :element do |event|
        event.element_value
      end

      # The element teams bring against that boss (integer), or null.
      field :advantage_element do |event|
        event.advantage_element
      end

      # Host-relative, like StickerBlueprint. Falls back to the series banner
      # for recurring events without their own.
      field :image_url do |event|
        if event.image_key.present?
          "#{event.image_key}?v=#{event.updated_at.to_i}"
        else
          event.banner_key
        end
      end

      # The Japanese banner (its art has Japanese text), versioned like
      # image_url. A series' Japanese banner may not exist yet: clients fall
      # back to image_url when this doesn't load.
      field :image_url_ja do |event|
        if event.image_key_jp.present?
          "#{event.image_key_jp}?v=#{event.updated_at.to_i}"
        else
          event.banner_key_jp
        end
      end

      # External pages: a gbf.wiki title, a GameWith article id, a Kamigame path under /グラブル/
      fields :wiki_en, :gamewith, :kamigame

      field :raids do |event|
        RaidBlueprint.render_as_hash(event.event_raids.map(&:raid), view: :list)
      end

      field :event_number, if: ->(_field, _event, options) { options[:editor] }
      field :source_refs, if: ->(_field, _event, options) { options[:editor] }
      field :source_payload, if: ->(_field, _event, options) { options[:editor] }
    end
  end
end

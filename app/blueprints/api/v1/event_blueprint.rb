# frozen_string_literal: true

module Api
  module V1
    # Callers preload `event_raids: { raid: :group }`. Pass `editor: true` to
    # include the sync bookkeeping fields.
    class EventBlueprint < ApiBlueprint
      field :name do |event|
        { en: event.name_en, ja: event.name_jp }
      end

      fields :kind, :series, :starts_at, :ends_at, :status, :raid_unlock_hour

      # The boss's element, as an integer from GranblueEnums::ELEMENTS (like
      # parties.element).
      field :element do |event|
        event.element_value
      end

      # A second boss element (integer), or null: Records of the Ten's Fire and
      # Dark run has Wind and Light bosses.
      field :second_element do |event|
        event.second_element_value
      end

      # The element teams bring against that boss (integer), or null.
      field :advantage_element do |event|
        event.advantage_element
      end

      # Every element teams can bring (integers): one, or two for a second
      # boss element. Empty without an element.
      field :advantage_elements do |event|
        event.advantage_elements
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

      # Each raid with the day it opens on (whole days after the start) and
      # when that is; both null when it opens with the event
      field :raids do |event|
        event.event_raids.map do |row|
          RaidBlueprint.render_as_hash(row.raid, view: :list)
                       .merge(unlock_day: row.unlock_day, unlocks_at: row.unlocks_at)
        end
      end

      field :event_number, if: ->(_field, _event, options) { options[:editor] }
      field :source_refs, if: ->(_field, _event, options) { options[:editor] }
      field :source_payload, if: ->(_field, _event, options) { options[:editor] }
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class StickerBlueprint < ApiBlueprint
      field :slug

      field :meaning do |sticker|
        { en: sticker.meaning_en, ja: sticker.meaning_jp }
      end

      # Host-relative (<key>?v=<timestamp>), like DifficultyBlueprint: the web
      # app prepends its image host. Versioned so a re-upload busts caches.
      field :image_url do |sticker|
        StickerBlueprint.image_url(sticker)
      end

      def self.image_url(sticker)
        return nil if sticker.image_key.blank?

        "#{sticker.image_key}?v=#{sticker.updated_at.to_i}"
      end

      fields :position, :active
    end
  end
end

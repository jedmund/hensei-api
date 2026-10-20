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

      # The Japanese image, or null when there's none (show image_url)
      field :image_url_ja do |sticker|
        StickerBlueprint.image_url(sticker, :image_key_jp)
      end

      def self.image_url(sticker, column = :image_key)
        key = sticker.public_send(column)
        return nil if key.blank?

        "#{key}?v=#{sticker.updated_at.to_i}"
      end

      fields :position, :active
    end
  end
end

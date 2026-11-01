# frozen_string_literal: true

module Api
  module V1
    module Admin
      # Editor-only sticker catalogue list for the database editor, and its
      # schema (GBF-143). The list is ordered by hand (PUT /stickers/reorder),
      # so its default sort is the picker order.
      class StickersController < Api::V1::ApiController
        include AdminCollection

        before_action :ensure_editor_role

        admin_collection Sticker do
          search :slug, :meaning_en, :meaning_jp

          filter :active, type: :boolean
          filter :updated_at, type: :datetime

          sort :position, :slug, :meaning_en, :meaning_jp, :updated_at, :created_at
          default_sort 'position', 'created_at'

          %i[slug meaning_en meaning_jp image_key image_key_jp position active
             created_at updated_at].each { |name| field name }

          # Versioned image paths, as the catalogue serves them
          field :image_url, value: ->(s) { Api::V1::StickerBlueprint.image_url(s) }
          field :image_url_ja, value: ->(s) { Api::V1::StickerBlueprint.image_url(s, :image_key_jp) }
          # How many teams carry it; a given sticker can't be deleted
          field :given_count, select: 'SELECT COUNT(*) FROM party_stickers ' \
                                      'WHERE party_stickers.sticker_id = stickers.id'

          default_fields :slug, :meaning_en, :meaning_jp, :image_url, :image_url_ja, :position, :active

          etag_sources :party_stickers

          writable Api::V1::StickersController::PERMITTED
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

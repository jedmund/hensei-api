# frozen_string_literal: true

# A sticker members give to a team to say why it's good. Editors manage the
# catalogue. Once given, a sticker can't be deleted, only retired (`active`):
# retired stickers leave the picker and stop showing as labels, but keep
# counting toward ranking.
class Sticker < ApplicationRecord
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  IMAGE_PREFIX = 'icons/stickers'

  # Cache key for the public catalogue (GET /stickers), busted on any write.
  CATALOGUE_CACHE_KEY = 'stickers/catalogue/v2'

  has_many :party_stickers, dependent: :restrict_with_error

  after_commit :bust_catalogue_cache

  validates :slug, presence: true, uniqueness: true, format: { with: SLUG_FORMAT }, length: { maximum: 64 }
  validates :meaning_en, presence: true, length: { maximum: 255 }
  validates :meaning_jp, length: { maximum: 255 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :created_at) }

  def blueprint
    Api::V1::StickerBlueprint
  end

  private

  def bust_catalogue_cache
    Rails.cache.delete(CATALOGUE_CACHE_KEY)
  end
end

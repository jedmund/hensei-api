# frozen_string_literal: true

class Awakening < ApplicationRecord
  # Lowercase words joined by hyphens (weapon-atk, character-multi). The slug
  # names the awakening's icon file, so it must stay path-safe.
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  IMAGE_PREFIX = 'icons/awakening'

  has_many :weapon_awakenings, foreign_key: :awakening_id
  has_many :weapons, through: :weapon_awakenings

  validates :slug, presence: true, format: { with: SLUG_FORMAT }, length: { maximum: 64 }

  # The web app reads character awakening icons as JPG and the rest as PNG
  # (getAwakeningImage in hensei-svelte), so uploads must match by slug.
  def image_formats
    slug.to_s.start_with?('character-') ? %w[JPEG] : %w[PNG]
  end

  def awakening
    AwakeningBlueprint
  end
end

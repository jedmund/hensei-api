# frozen_string_literal: true

class Awakening < ApplicationRecord
  # Lowercase words joined by hyphens (weapon-atk, character-multi). The slug
  # names the awakening's icon file, so it must stay path-safe.
  SLUG_FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  IMAGE_PREFIX = 'icons/awakening'

  has_many :weapon_awakenings, foreign_key: :awakening_id
  has_many :weapons, through: :weapon_awakenings

  validates :slug, presence: true, format: { with: SLUG_FORMAT }, length: { maximum: 64 }

  def awakening
    AwakeningBlueprint
  end
end

# frozen_string_literal: true

class Awakening < ApplicationRecord
  # The slug names the awakening's icon file (weapon-atk, character-multi).
  include Slugged

  IMAGE_PREFIX = 'icons/awakening'
  # What an awakening applies to: collection items check it against their own type
  OBJECT_TYPES = %w[Character Weapon].freeze

  has_many :weapon_awakenings, foreign_key: :awakening_id
  has_many :weapons, through: :weapon_awakenings

  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :object_type, inclusion: { in: OBJECT_TYPES }
  validates :order, numericality: { only_integer: true }

  # The web app reads character awakening icons as JPG and the rest as PNG
  # (getAwakeningImage in hensei-svelte), so uploads must match by slug.
  def image_formats
    slug.to_s.start_with?('character-') ? %w[JPEG] : %w[PNG]
  end

  def awakening
    AwakeningBlueprint
  end
end

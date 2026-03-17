# frozen_string_literal: true

class WeaponSeries < ApplicationRecord
  has_many :weapons, dependent: :restrict_with_error
  has_many :weapon_series_variants, dependent: :destroy
  has_many :weapon_key_series, dependent: :destroy
  has_many :weapon_keys, through: :weapon_key_series

  enum :augment_type, { no_augment: 0, ax: 1, befoulment: 2 }, default: :no_augment

  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :order, numericality: { only_integer: true }

  scope :ordered, -> { order(:order) }
  scope :extra_allowed, -> { where(extra: true) }
  scope :element_changeable, -> { where(element_changeable: true) }
  scope :with_weapon_keys, -> { where(has_weapon_keys: true) }
  scope :with_awakening, -> { where(has_awakening: true) }
  scope :with_ax_skills, -> { where(augment_type: :ax) }
  scope :with_befoulments, -> { where(augment_type: :befoulment) }

  # Slug constants for commonly referenced series
  DARK_OPUS = 'dark-opus'
  DRACONIC = 'draconic'
  DRACONIC_PROVIDENCE = 'draconic-providence'
  REVENANT = 'revenant'
  ULTIMA = 'ultima'
  SUPERLATIVE = 'superlative'
  CLASS_CHAMPION = 'class-champion'

  def blueprint
    WeaponSeriesBlueprint
  end
end

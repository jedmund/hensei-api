# frozen_string_literal: true

class WeaponSeries < ApplicationRecord
  include Slugged
  include UniqueOrder

  has_many :weapons, dependent: :restrict_with_error
  has_many :weapon_series_variants, dependent: :destroy
  has_many :weapon_key_series, dependent: :destroy
  has_many :weapon_keys, through: :weapon_key_series

  enum :augment_type, { no_augment: 0, ax: 1, befoulment: 2 }, default: :no_augment, validate: true

  validates :name_en, presence: true
  validates :name_jp, presence: true
  validates :order, numericality: { only_integer: true }
  validates :num_weapon_keys, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :key_slot_min_uncaps_fit_slots

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

  private

  # One uncap level (0–5; no key unlock needs transcendence) per key slot, at most num_weapon_keys of them.
  def key_slot_min_uncaps_fit_slots
    levels = Array(key_slot_min_uncaps)
    errors.add(:key_slot_min_uncaps, 'must be uncap levels from 0 to 5') unless levels.all? { |l| (0..5).cover?(l) }
    return if num_weapon_keys.nil? || levels.size <= num_weapon_keys

    errors.add(:key_slot_min_uncaps, 'has more entries than key slots')
  end
end

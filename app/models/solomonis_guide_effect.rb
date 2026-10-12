# frozen_string_literal: true

##
# An Evoking Solomonis guidebook effect (catalogue), keyed by the game's
# status_id. Names may hold a `{value}` placeholder for run-dependent numbers.
# Either name may be null, but not both; the UI shows the other in its place.
class SolomonisGuideEffect < ApplicationRecord
  RARITIES = %w[normal rare unique cursed].freeze
  # The game's `rarity` field.
  GAME_RARITIES = { 1 => 'normal', 2 => 'rare', 3 => 'unique', 99 => 'cursed' }.freeze
  TARGET_TYPES = %w[race proficiency character].freeze
  # The game's `target_type` field.
  GAME_TARGET_TYPES = { 1 => 'race', 2 => 'proficiency', 3 => 'character' }.freeze
  AVAILABILITIES = %w[global event character].freeze
  NAME_MAX_LENGTH = 1000
  TAG_MAX_LENGTH = 32
  MAX_TAGS = 20

  belongs_to :character, optional: true
  has_many :expedition_guide_effects, dependent: :restrict_with_error

  validates :granblue_id, presence: true, uniqueness: true,
                          numericality: { only_integer: true, greater_than: 0, less_than: 2**31 }
  validates :rarity, inclusion: { in: RARITIES }
  validates :stackable, inclusion: { in: [true, false] }
  validates :name_en, :name_jp, length: { maximum: NAME_MAX_LENGTH }, allow_nil: true
  validates :target_type, inclusion: { in: TARGET_TYPES }, allow_nil: true
  validates :availability, inclusion: { in: AVAILABILITIES }, allow_nil: true
  validates :icon_category, :icon_type, numericality: { only_integer: true }, allow_nil: true
  validate :name_present
  validate :target_values_are_integers
  validate :tags_are_short_strings

  scope :ordered, -> { order(:granblue_id) }
  scope :by_rarity, ->(rarity) { where(rarity: rarity) if rarity.present? }

  private

  def name_present
    errors.add(:name_en, 'or name_jp must be present') if name_en.blank? && name_jp.blank?
  end

  def target_values_are_integers
    return if target_values.is_a?(Array) && target_values.all? { |v| v.is_a?(Integer) && v.between?(0, (2**31) - 1) }

    errors.add(:target_values, 'must be a list of integers')
  end

  def tags_are_short_strings
    %i[type_tags effect_tags].each do |attr|
      tags = self[attr]
      next if tags.nil?

      valid = tags.is_a?(Array) && tags.size <= MAX_TAGS &&
              tags.all? { |t| t.is_a?(String) && t.present? && t.length <= TAG_MAX_LENGTH }
      errors.add(attr, 'must be a short list of short strings') unless valid
    end
  end
end

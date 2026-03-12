# frozen_string_literal: true

class Character < ApplicationRecord
  include PgSearch::Model

  has_many :character_series_memberships, dependent: :destroy
  has_many :character_series_records, through: :character_series_memberships, source: :character_series

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |character|
                    {
                      name_en: character.name_en,
                      name_jp: character.name_jp,
                      granblue_id: character.granblue_id,
                      element: character.element
                    }
                  }

  pg_search_scope :en_search,
                  against: %i[name_en nicknames_en],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    },
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :ja_search,
                  against: %i[name_jp nicknames_jp],
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  AWAKENINGS = [
    { slug: 'character-balanced', name_en: 'Balanced', name_jp: 'バランス', order: 0 },
    { slug: 'character-atk', name_en: 'Attack', name_jp: '攻撃', order: 1 },
    { slug: 'character-def', name_en: 'Defense', name_jp: '防御', order: 2 },
    { slug: 'character-multi', name_en: 'Multiattack', name_jp: '連続攻撃', order: 3 }
  ].freeze


  # Validations
  validates :season,
            numericality: { only_integer: true },
            inclusion: { in: GranblueEnums::CHARACTER_SEASONS.values },
            allow_nil: true

  validate :validate_series_values

  # Scopes
  scope :by_season, ->(season) { where(season: season) }
  scope :by_series, ->(series) { where('? = ANY(series)', series) }
  scope :seasonal, -> { where.not(season: [nil, GranblueEnums::CHARACTER_SEASONS[:Standard]]) }
  scope :style_swap_variants, -> { where(style_swap: true) }
  scope :base_characters, -> { where(style_swap: false) }

  def blueprint
    CharacterBlueprint
  end

  def display_resource(character)
    character.name_en
  end

  # Helper methods
  def seasonal?
    season.present? && season != GranblueEnums::CHARACTER_SEASONS[:Standard]
  end

  def season_name
    return nil if season.nil?

    GranblueEnums::CHARACTER_SEASONS.key(season)&.to_s
  end

  def series_names
    # Use new lookup table if available
    if character_series_records.loaded? ? character_series_records.any? : character_series_records.exists?
      character_series_records.ordered.pluck(:name_en)
    elsif series.present?
      # Legacy fallback
      series.filter_map { |s| GranblueEnums::CHARACTER_SERIES.key(s)&.to_s }
    else
      []
    end
  end

  def series_objects
    character_series_records.ordered
  end

  def series_slugs
    character_series_records.pluck(:slug)
  end

  # Style swap helpers — derived from shared granblue_id
  def base_character
    return nil unless style_swap? && granblue_id.present?

    Character.where(granblue_id: granblue_id, style_swap: false).first
  end

  def style_swaps
    return Character.none if style_swap? || granblue_id.blank?

    Character.where(granblue_id: granblue_id, style_swap: true).where.not(id: id)
  end

  # Mapping from legacy integer values to slugs
  LEGACY_SERIES_TO_SLUG = {
    1 => 'grand',
    2 => 'zodiac',
    3 => 'promo',
    4 => 'collab',
    5 => 'eternal',
    6 => 'evoker',
    7 => 'saint',
    8 => 'fantasy',
    9 => 'summer',
    10 => 'yukata',
    11 => 'valentine',
    12 => 'halloween',
    13 => 'formal',
    14 => 'holiday',
    15 => 'event'
  }.freeze

  # Virtual attribute to set character_series by array of IDs, slugs, or legacy integers
  # Supports multiple formats for flexibility during migration
  def series=(values)
    return if values.blank?

    # Ensure it's an array
    values = Array(values)

    values.each do |value|
      next if value.blank?

      # Try to find the series record
      series_record = if value.is_a?(Integer)
                        # Legacy integer - convert to slug first
                        slug = LEGACY_SERIES_TO_SLUG[value]
                        slug ? CharacterSeries.find_by(slug: slug) : nil
                      else
                        # String - try UUID first, then slug
                        CharacterSeries.find_by(id: value) || CharacterSeries.find_by(slug: value)
                      end

      next unless series_record

      # Create membership if it doesn't exist
      character_series_memberships.find_or_initialize_by(character_series: series_record)
    end
  end

  private

  def validate_series_values
    return if series.blank?

    invalid_values = series.reject { |s| GranblueEnums::CHARACTER_SERIES.values.include?(s) }
    return if invalid_values.empty?

    errors.add(:series, "contains invalid values: #{invalid_values.join(', ')}")
  end
end

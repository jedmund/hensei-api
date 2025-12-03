# frozen_string_literal: true

class Weapon < ApplicationRecord
  include PgSearch::Model

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |weapon|
                    {
                      name_en: weapon.name_en,
                      name_jp: weapon.name_jp,
                      granblue_id: weapon.granblue_id,
                      element: weapon.element
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

  has_many :weapon_awakenings
  has_many :awakenings, through: :weapon_awakenings
  belongs_to :weapon_series, optional: true

  # Legacy mapping - kept for backwards compatibility during migration
  # TODO: Remove after data migration is complete
  SERIES_SLUGS = {
    1 => 'seraphic',
    2 => 'grand',
    3 => 'dark-opus',
    4 => 'revenant',
    5 => 'primal',
    6 => 'beast',
    7 => 'regalia',
    8 => 'omega',
    9 => 'olden-primal',
    10 => 'hollowsky',
    11 => 'xeno',
    12 => 'rose',
    13 => 'ultima',
    14 => 'bahamut',
    15 => 'epic',
    16 => 'cosmos',
    17 => 'superlative',
    18 => 'vintage',
    19 => 'class-champion',
    20 => 'replica',
    21 => 'relic',
    22 => 'rusted',
    23 => 'sephira',
    24 => 'vyrmament',
    25 => 'upgrader',
    26 => 'astral',
    27 => 'draconic',
    28 => 'eternal-splendor',
    29 => 'ancestral',
    30 => 'new-world-foundation',
    31 => 'ennead',
    32 => 'militis',
    33 => 'malice',
    34 => 'menace',
    35 => 'illustrious',
    36 => 'proven',
    37 => 'revans',
    38 => 'world',
    39 => 'exo',
    40 => 'draconic-providence',
    41 => 'celestial',
    42 => 'omega-rebirth',
    43 => 'collab',
    98 => 'event',
    99 => 'gacha'
  }.freeze

  def blueprint
    WeaponBlueprint
  end

  def display_resource(weapon)
    weapon.name_en
  end

  def compatible_with_key?(key)
    return false unless weapon_series.present?

    key.weapon_series.include?(weapon_series)
  end

  # Returns whether the weapon is included in the Draconic or Dark Opus series
  def opus_or_draconic?
    return false unless weapon_series.present?

    [WeaponSeries::DARK_OPUS, WeaponSeries::DRACONIC].include?(weapon_series.slug)
  end

  # Returns whether the weapon belongs to the Draconic Weapon series or the Draconic Weapon Providence series
  def draconic_or_providence?
    return false unless weapon_series.present?

    [WeaponSeries::DRACONIC, WeaponSeries::DRACONIC_PROVIDENCE].include?(weapon_series.slug)
  end

  def self.element_changeable?(weapon_or_series)
    if weapon_or_series.is_a?(Weapon)
      weapon_or_series.weapon_series&.element_changeable || false
    elsif weapon_or_series.is_a?(WeaponSeries)
      weapon_or_series.element_changeable
    elsif weapon_or_series.is_a?(Integer)
      # Legacy support for integer series IDs during transition
      [4, 13, 17, 19].include?(weapon_or_series)
    else
      false
    end
  end

  # Promotion scopes
  scope :by_promotion, ->(promotion) { where('? = ANY(promotions)', promotion) }
  scope :in_premium, -> { by_promotion(GranblueEnums::PROMOTIONS[:Premium]) }
  scope :in_classic, -> { by_promotion(GranblueEnums::PROMOTIONS[:Classic]) }
  scope :flash_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Flash]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Legend]) }
  scope :legend_exclusive, -> { by_promotion(GranblueEnums::PROMOTIONS[:Legend]).where.not('? = ANY(promotions)', GranblueEnums::PROMOTIONS[:Flash]) }

  # Promotion helpers
  def flash?
    promotions.include?(GranblueEnums::PROMOTIONS[:Flash])
  end

  def legend?
    promotions.include?(GranblueEnums::PROMOTIONS[:Legend])
  end

  def premium?
    promotions.include?(GranblueEnums::PROMOTIONS[:Premium])
  end

  def promotion_names
    promotions.filter_map { |p| GranblueEnums::PROMOTIONS.key(p)&.to_s }
  end

  def series_slug
    weapon_series&.slug || SERIES_SLUGS[series]
  end
end

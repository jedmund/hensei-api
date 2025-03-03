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
  has_many :weapon_skills,
           primary_key: 'granblue_id',
           foreign_key: 'weapon_granblue_id'
  has_many :skills,
           through: :weapon_skills
  has_many :charge_attacks,
           -> { where(owner_type: 'weapon') },
           primary_key: 'granblue_id',
           foreign_key: 'owner_id'

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
    key.series.include?(series)
  end

  # Returns whether the weapon is included in the Draconic or Dark Opus series
  def opus_or_draconic?
    [3, 27].include?(series)
  end

  # Returns whether the weapon belongs to the Draconic Weapon series or the Draconic Weapon Providence series
  def draconic_or_providence?
    [27, 40].include?(series)
  end

  def self.element_changeable?(series)
    [4, 13, 17, 19].include?(series.to_i)
  end

  private

  def series_slug
    # Assuming series is an array, take the first value
    series_number = series.first
    SERIES_SLUGS[series_number]
  end
end

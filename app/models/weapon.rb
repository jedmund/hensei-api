# frozen_string_literal: true

class Weapon < ApplicationRecord
  include PgSearch::Model

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    trigram: {
                      threshold: 0.18
                    }
                  }

  pg_search_scope :ja_search,
                  against: :name_jp,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  has_many :weapon_awakenings
  has_many :awakenings, through: :weapon_awakenings

  def blueprint
    WeaponBlueprint
  end

  def display_resource(weapon)
    weapon.name_en
  end

  def compatible_with_key?(key)
    key.series == series
  end

  # Returns whether the weapon is included in the Draconic or Dark Opus series
  def opus_or_draconic?
    [2, 3].include?(series)
  end
end

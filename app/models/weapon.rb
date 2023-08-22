# frozen_string_literal: true

class Weapon < ApplicationRecord
  include PgSearch::Model

  multisearchable against: %i[name_en name_jp],
                  additional_attributes: lambda { |weapon|
                    {
                      name_en: weapon.name_en,
                      name_jp: weapon.name_jp,
                      nicknames_en: weapon.nicknames_en,
                      nicknames_jp: weapon.nicknames_jp,
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

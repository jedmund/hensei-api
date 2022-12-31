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

  pg_search_scope :jp_search,
                  against: :name_jp,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
                    }
                  }

  def blueprint
    WeaponBlueprint
  end

  def display_resource(weapon)
    weapon.name_en
  end

  def compatible_with_key?(key)
    key.series == series
  end
end

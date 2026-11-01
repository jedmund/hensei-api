# frozen_string_literal: true

class JobAccessory < ApplicationRecord
  include PgSearch::Model

  belongs_to :job

  # Shields (Paladin, Shieldsworn) and manaturas (Manadiver, Wizard Origin).
  ACCESSORY_TYPES = { Shield: 1, Manatura: 2 }.freeze
  RARITY_VALUES = GranblueEnums::RARITIES

  validates :granblue_id, presence: true, format: { with: /\A\d+\z/ }, uniqueness: true
  validates :name_en, :name_jp, presence: true
  validates :accessory_type, inclusion: { in: ACCESSORY_TYPES.values }
  validates :rarity, inclusion: { in: RARITY_VALUES.values }, allow_nil: true

  pg_search_scope :en_search,
                  against: :name_en,
                  using: {
                    tsearch: {
                      prefix: true,
                      dictionary: 'simple'
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
    JobAccessoryBlueprint
  end

  def display_resource(skill)
    skill.name_en
  end

  def ==(other)
    self.class == other.class && id == other.id
  end
end

# frozen_string_literal: true

##
# A Wonder (大事なもの) from the catalogue. Three kinds:
# - `leveled` (Crucible Seals, Yupei): bonuses grow with level, summed from
#   level_bonuses; Seals' evolution raises the level cap (evolution_caps).
# - `scaling` (Symbolum Amicitiae): its bonus comes from a character count.
# - `fixed`: everything else; its effects are the linked wonder_effects.
#
# element is a GranblueEnums::ELEMENTS value, or nil for all elements.
# Seeded by a data migration from db/data/wonders/catalogue.json.
class Wonder < ApplicationRecord
  KINDS = %w[fixed leveled scaling].freeze

  belongs_to :wonder_category, inverse_of: :wonders
  has_many :wonder_effect_links, -> { order(:position) }, dependent: :delete_all, inverse_of: :wonder
  has_many :wonder_effects, through: :wonder_effect_links
  has_many :level_bonuses, -> { order(:level) }, class_name: 'WonderLevelBonus', dependent: :delete_all,
                                                 inverse_of: :wonder
  has_many :evolution_caps, -> { order(:evolution) }, class_name: 'WonderEvolutionCap', dependent: :delete_all,
                                                      inverse_of: :wonder
  has_many :collection_wonders, dependent: :restrict_with_error
  has_many :party_wonders, dependent: :restrict_with_error

  validates :granblue_id, presence: true, uniqueness: true
  validates :name_en, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :max_evolution, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :max_level, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :max_level, presence: true, if: :leveled?
  validates :element, inclusion: { in: GranblueEnums::ELEMENTS.values }, allow_nil: true

  scope :ordered, -> { joins(:wonder_category).order('wonder_categories.sort_order', :sort_order) }

  KINDS.each do |name|
    define_method(:"#{name}?") { kind == name }
  end

  ##
  # The highest level allowed at an evolution: the evolution cap when the
  # Wonder has them (Seals), max_level otherwise. nil for unknown evolutions
  # and for Wonders without levels.
  def level_cap(evolution)
    return nil unless leveled?

    caps = evolution_caps.to_a
    return max_level if caps.empty?

    caps.find { |cap| cap.evolution == evolution.to_i }&.max_level
  end

  # The bonuses at a level or character count; see WonderBonusCalculator.
  def bonuses_at(level: nil, possession: nil)
    WonderBonusCalculator.for(self, level: level, possession: possession)
  end
end

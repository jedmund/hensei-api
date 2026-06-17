# frozen_string_literal: true

# One tier of a weapon skill slot (base / FLB / ULB / Transcendence stage).
# Content (name/description) is canonical on the shared Skill catalog and read
# through #skill — never duplicated here. The version carries only the
# tier requirement and parser-derived scaling/condition attributes.
class WeaponSkillVersion < ApplicationRecord
  belongs_to :weapon_skill, inverse_of: :weapon_skill_versions
  belongs_to :skill

  # Which summon auras boost this skill (see WeaponSkill history for details).
  enum :skill_series, {
    normal: 'normal',
    omega: 'omega',
    ex: 'ex',
    odious: 'odious'
  }

  enum :skill_size, {
    small: 'small',
    medium: 'medium',
    big: 'big',
    big_ii: 'big_ii',
    massive: 'massive',
    unworldly: 'unworldly',
    ancestral: 'ancestral'
  }

  VALID_MODIFIERS = Granblue::Parsers::WeaponSkillParser::KNOWN_MODIFIERS

  # skill presence is enforced by the required belongs_to :skill above.
  validates :ordinal, presence: true,
                      numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :min_uncap, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :transcendence_stage, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :skill_modifier, inclusion: { in: VALID_MODIFIERS }, allow_nil: true

  delegate :name_en, :name_jp, :description_en, :description_jp, to: :skill, allow_nil: true

  # Standard-modifier skills scale with skill level via the lookup table.
  # Unique/fixed-effect skills (nil modifier) return nothing here.
  def weapon_skill_data
    WeaponSkillDatum.for_skill(modifier: skill_modifier, series: skill_series, size: skill_size)
  end
end

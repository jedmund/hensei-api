# frozen_string_literal: true

class WeaponSkill < ApplicationRecord
  belongs_to :weapon, primary_key: :granblue_id, foreign_key: :weapon_granblue_id, inverse_of: :weapon_skills
  belongs_to :skill

  # Skill series determines which summon auras boost this skill.
  # normal  — boosted by Optimus summons (Agni, Varuna, Titan, Zephyrus, Zeus, Hades)
  # omega   — boosted by Omega summons (Colossus, Leviathan, Yggdrasil, Tiamat, Luminiera, Celeste)
  # ex      — not boosted by any summon aura
  # odious  — boosted by Odious summons
  # nil     — weapon-specific skills (Militis, CCW, Archangel, Ennead, Arcana, etc.)
  enum :skill_series, {
    normal: 'normal',
    omega: 'omega',
    ex: 'ex',
    odious: 'odious'
  }

  # Skill size determines the base value of the skill effect.
  enum :skill_size, {
    small: 'small',
    medium: 'medium',
    big: 'big',
    big_ii: 'big_ii',
    massive: 'massive',
    unworldly: 'unworldly',
    ancestral: 'ancestral'
  }

  # Valid modifiers sourced from WeaponSkillParser.
  # Each modifier represents a distinct effect type (e.g. Might = ATK, Enmity = ATK from low HP).
  VALID_MODIFIERS = Granblue::Parsers::WeaponSkillParser::KNOWN_MODIFIERS

  validates :weapon_granblue_id, presence: true
  validates :skill_id, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: [:weapon_granblue_id, :uncap_level] }
  validates :uncap_level, presence: true,
                          numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :skill_modifier, inclusion: { in: VALID_MODIFIERS }, allow_nil: true
end

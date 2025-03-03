# frozen_string_literal: true

class Skill < ApplicationRecord
  has_many :skill_values
  has_many :skill_effects
  has_many :effects, through: :skill_effects
  has_many :character_skills
  has_many :weapon_skills
  has_many :summon_calls
  has_many :charge_attacks
  has_many :alt_character_skills, class_name: 'CharacterSkill', foreign_key: 'alt_skill_id'
  has_many :alt_summon_calls, class_name: 'SummonCall', foreign_key: 'alt_skill_id'
  has_many :alt_charge_attacks, class_name: 'ChargeAttack', foreign_key: 'alt_skill_id'

  validates :name_en, presence: true
  validates :skill_type, presence: true

  enum skill_type: { character: 1, weapon: 2, summon_call: 3, charge_attack: 4 }
  enum border_type: { damage: 1, healing: 2, buff: 3, debuff: 4, field: 5 }

  def value_at_level(level)
    skill_values.find_by(level: level)
  end
end

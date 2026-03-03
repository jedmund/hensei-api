# frozen_string_literal: true

class Skill < ApplicationRecord
  enum :skill_type, { character: 0, charge_attack: 1, summon: 2, weapon: 3 }

  has_many :weapon_skills, dependent: :destroy

  validates :name_en, presence: true
end

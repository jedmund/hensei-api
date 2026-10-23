# frozen_string_literal: true

class Skill < ApplicationRecord
  enum :skill_type, { character: 0, charge_attack: 1, summon: 2, weapon: 3 }

  # A shared skill can't be deleted out from under the weapon versions using it
  # (that cascaded away version-linked curation).
  has_many :weapon_skill_versions, dependent: :restrict_with_error

  validates :name_en, presence: true
end

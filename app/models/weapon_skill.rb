# frozen_string_literal: true

# A weapon skill SLOT (position) on a weapon. The skill's content and how it
# evolves across uncap/transcendence tiers live in weapon_skill_versions.
class WeaponSkill < ApplicationRecord
  belongs_to :weapon, primary_key: :granblue_id, foreign_key: :weapon_granblue_id, inverse_of: :weapon_skills
  has_many :weapon_skill_versions, -> { order(:ordinal) }, dependent: :destroy, inverse_of: :weapon_skill

  validates :weapon_granblue_id, presence: true
  validates :position, presence: true,
                       numericality: { only_integer: true, greater_than_or_equal_to: 0 },
                       uniqueness: { scope: :weapon_granblue_id }
end

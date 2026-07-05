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

  # The version active at a grid weapon's current uncap/transcendence: the highest
  # tier whose unlock (min_uncap / transcendence_stage) the weapon has reached.
  # min_uncap 3 = base (always available, so uncap is clamped to >= 3).
  def active_version(uncap_level:, transcendence_step: 0)
    eff_uncap = [uncap_level.to_i, 3].max
    weapon_skill_versions
      .select { |v| (v.min_uncap || 3) <= eff_uncap && (v.transcendence_stage || 0) <= transcendence_step.to_i }
      .max_by { |v| [v.min_uncap || 3, v.transcendence_stage || 0, v.ordinal] }
  end
end

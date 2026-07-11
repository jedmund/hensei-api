# frozen_string_literal: true

# A conditional / fixed-mechanic grid boost (the "prose" weapon skills).
# Complements WeaponSkillDatum (SL-grid scaling): a skill type may have rows in
# both. See docs/damage/08-scaling-data-pipeline.md, 09-calculator-mvp.md.
class WeaponSkillEffect < ApplicationRecord
  SCALING_KINDS = %w[supplemental_cap per_grid_count conditional_flat
                     ally_hp_scaled ally_max_hp_scaled current_hp_scaled bonus_dmg flat static
                     specialty_scaled persistence_supp hp_linear_cutoff
                     hp_current_linear hp_missing_linear documentation].freeze
  VALUE_UNITS = %w[percent percent_foe_max_hp percent_ally_max_hp flat].freeze
  SERIES_VALUES = %w[normal omega ex odious].freeze
  TARGET_INSTANCES = %w[all normal_attack charge_attack skill critical].freeze
  STACKINGS = %w[additive highest_only].freeze
  APPLIES_TO = %w[element_allies all_allies mc_only].freeze

  # Per-version rows (description-driven extraction) link straight to the version.
  belongs_to :weapon_skill_version, optional: true

  validates :modifier, presence: true
  validates :boost_type, presence: true
  validates :scaling_kind, inclusion: { in: SCALING_KINDS }
  validates :value_unit, inclusion: { in: VALUE_UNITS }, allow_nil: true
  validates :series, inclusion: { in: SERIES_VALUES }, allow_nil: true
  validates :target_instance, inclusion: { in: TARGET_INSTANCES }, allow_nil: true
  validates :stacking, inclusion: { in: STACKINGS }
  validates :applies_to, inclusion: { in: APPLIES_TO }
  validate :count_basis_is_canonical
  # condition is in the scope so tiered key upgrades (Δ/γ Pendulum at transcendence
  # steps 1/4) can coexist as separate rows under one modifier.
  validates :modifier, uniqueness: { scope: %i[boost_type scaling_kind key_slug weapon_skill_version_id condition] }

  # Conditional/fixed effects for a weapon-skill version, keyed by modifier.
  scope :for_skill, ->(modifier:) { where(modifier: modifier) }
  # Effects granted by an equipped weapon key (Dark Opus pendulum/teluma, Draconic teluma,
  # Destroyer anklet); base-weapon effects have key_slug = nil.
  scope :for_key, ->(slug) { where(key_slug: slug) }
  # Canonical modifier-keyed effects (not key- or version-scoped).
  scope :base_effects, -> { where(key_slug: nil, weapon_skill_version_id: nil) }

  private

  def count_basis_is_canonical
    return if count_basis.blank?
    return if GridDamage::GridComposition.valid_count_basis?(count_basis)

    errors.add(:count_basis, "must be a canonical GridComposition count basis")
  end
end

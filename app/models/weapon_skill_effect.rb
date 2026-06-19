# frozen_string_literal: true

# A conditional / fixed-mechanic grid boost (the "prose" weapon skills).
# Complements WeaponSkillDatum (SL-grid scaling): a skill type may have rows in
# both. See docs/damage/08-scaling-data-pipeline.md, 09-calculator-mvp.md.
class WeaponSkillEffect < ApplicationRecord
  SCALING_KINDS = %w[foe_hp_supplemental per_grid_count conditional_flat
                     ally_hp_scaled current_hp_scaled bonus_dmg flat static].freeze
  VALUE_UNITS = %w[percent percent_foe_max_hp percent_ally_max_hp flat].freeze
  SERIES_VALUES = %w[normal omega ex].freeze
  TARGET_INSTANCES = %w[all normal_attack charge_attack skill critical].freeze
  STACKINGS = %w[additive highest_only].freeze
  APPLIES_TO = %w[element_allies all_allies mc_only].freeze

  validates :modifier, presence: true
  validates :boost_type, presence: true
  validates :scaling_kind, inclusion: { in: SCALING_KINDS }
  validates :value_unit, inclusion: { in: VALUE_UNITS }, allow_nil: true
  validates :series, inclusion: { in: SERIES_VALUES }, allow_nil: true
  validates :target_instance, inclusion: { in: TARGET_INSTANCES }, allow_nil: true
  validates :stacking, inclusion: { in: STACKINGS }
  validates :applies_to, inclusion: { in: APPLIES_TO }
  validates :modifier, uniqueness: { scope: %i[boost_type scaling_kind key_slug] }

  # Conditional/fixed effects for a weapon-skill version, keyed by modifier.
  scope :for_skill, ->(modifier:) { where(modifier: modifier) }
  # Effects granted by an equipped weapon key (Dark Opus pendulum/teluma, Draconic teluma,
  # Destroyer anklet); base-weapon effects have key_slug = nil.
  scope :for_key, ->(slug) { where(key_slug: slug) }
  scope :base_effects, -> { where(key_slug: nil) }
end

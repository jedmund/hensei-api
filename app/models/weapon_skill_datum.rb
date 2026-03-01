# frozen_string_literal: true

class WeaponSkillDatum < ApplicationRecord
  self.table_name = "weapon_skill_data"

  SERIES_VALUES = %w[normal omega ex odious normal_omega sephira].freeze
  SIZE_VALUES = %w[small medium big big_ii massive unworldly ancestral].freeze
  FORMULA_TYPES = %w[flat enmity stamina garrison].freeze

  validates :modifier, presence: true
  validates :boost_type, presence: true
  validates :series, presence: true, inclusion: { in: SERIES_VALUES }
  validates :size, presence: true, inclusion: { in: SIZE_VALUES }
  validates :formula_type, presence: true, inclusion: { in: FORMULA_TYPES }

  validates :modifier, uniqueness: { scope: [:boost_type, :series, :size] }

  # Look up all data rows for a given weapon skill's modifier/series/size.
  # Returns the boost types and their SL values for damage calculation.
  scope :for_skill, ->(modifier:, series:, size:) {
    where(modifier: modifier, series: series, size: size)
  }
end

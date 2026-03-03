# frozen_string_literal: true

class WeaponSkillDatum < ApplicationRecord
  self.table_name = "weapon_skill_data"

  SERIES_VALUES = %w[normal omega ex odious normal_omega sephira unique].freeze
  SIZE_VALUES = %w[small medium big big_ii massive unworldly ancestral].freeze
  FORMULA_TYPES = %w[flat enmity stamina garrison].freeze

  validates :modifier, presence: true
  validates :boost_type, presence: true
  validates :series, inclusion: { in: SERIES_VALUES }, allow_nil: true
  validates :size, presence: true, inclusion: { in: SIZE_VALUES }
  validates :formula_type, presence: true, inclusion: { in: FORMULA_TYPES }

  validates :modifier, uniqueness: { scope: [:boost_type, :series, :size] }

  # Look up all data rows for a given weapon skill's modifier/series/size.
  # Returns the boost types and their SL values for damage calculation.
  #
  # When series is nil (non-standard skills like Sephira, unique), looks up
  # by modifier only — these modifiers exist in only one series each.
  # When size is nil (skills without numerals), also omits the size filter.
  # When series is "normal" or "omega" and no results found, falls back to
  # "normal_omega" — these modifiers share SL values across both series.
  scope :for_skill, ->(modifier:, series: nil, size: nil) {
    q = where(modifier: modifier)
    q = q.where(series: series) if series
    q = q.where(size: size) if size

    if series.in?(%w[normal omega]) && !q.exists?
      q = where(modifier: modifier, series: "normal_omega")
      q = q.where(size: size) if size
    end

    q
  }
end

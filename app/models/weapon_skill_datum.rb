# frozen_string_literal: true

class WeaponSkillDatum < ApplicationRecord
  self.table_name = "weapon_skill_data"

  SERIES_VALUES = %w[normal omega ex odious normal_omega sephira unique taboo].freeze
  SIZE_VALUES = %w[small medium big big_ii massive unworldly ancestral].freeze
  FORMULA_TYPES = %w[flat enmity stamina garrison progression].freeze

  # Per-version rows (description-driven extraction) link straight to the version; canonical
  # modifier-keyed rows leave it nil.
  belongs_to :weapon_skill_version, optional: true

  validates :modifier, presence: true
  validates :boost_type, presence: true
  validates :series, inclusion: { in: SERIES_VALUES }, allow_nil: true
  validates :size, inclusion: { in: SIZE_VALUES }, allow_nil: true # nil = sizeless (Shape B)
  validates :formula_type, presence: true, inclusion: { in: FORMULA_TYPES }

  validates :modifier, uniqueness: { scope: %i[boost_type series size weapon_skill_version_id] }

  scope :canonical, -> { where(weapon_skill_version_id: nil) }

  # The representative SL-curve for a tier — the strongest (max sl15) canonical row for the
  # (boost_type, size) tier. SL VALUES are series-independent (the frame only decides which aura
  # boosts the skill), so this is matched across series so EX/Omega skills reuse the same curve.
  def self.canonical_curve(boost_type:, size:, formula_type: "flat")
    canonical.where(boost_type: boost_type, size: size, formula_type: formula_type)
             .max_by { |d| d.sl15.to_f }
  end

  # Look up all data rows for a given weapon skill's modifier/series/size.
  # Returns the boost types and their SL values for damage calculation.
  #
  # When series is nil (non-standard skills like Sephira, unique), looks up
  # by modifier only — these modifiers exist in only one series each.
  # When size is nil (skills without numerals), also omits the size filter.
  # When series is "normal" or "omega" and no results found, falls back to
  # "normal_omega" — these modifiers share SL values across both series.
  # Resolve a weapon-skill version (modifier/series/size) to its scaling rows,
  # cascading through fallbacks (most-specific first):
  #   1. exact (modifier [+ series] [+ size])
  #   2. normal/omega/odious share a combined "normal_omega" row
  #   3. series-agnostic (modifier + size) — sizeless data or series drift
  #   4. modifier-only (last resort)
  scope :for_skill, ->(modifier:, series: nil, size: nil) {
    base = where(modifier: modifier)
    return base unless base.exists? # unknown modifier → empty relation

    exact = base
    exact = exact.where(series: series) if series
    exact = exact.where(size: size) if size
    return exact if exact.exists?

    if series.present?
      combined = base.where(series: "normal_omega")
      combined = combined.where(size: size) if size
      return combined if combined.exists?
    end

    if size
      sized = base.where(size: size)
      return sized if sized.exists?
    end

    base
  }
end

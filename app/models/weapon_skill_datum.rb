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

  # Series a version's series also matches in the data: normal and omega share combined
  # "normal_omega" rows; "odious" and "taboo" are the same frame under two names.
  SERIES_FALLBACK = {
    "normal" => %w[normal normal_omega], "omega" => %w[omega normal_omega],
    "odious" => %w[odious taboo], "taboo" => %w[taboo odious]
  }.freeze

  # Resolve a weapon-skill version's (modifier, series, size) to its canonical scaling
  # rows — AT MOST ONE row per boost_type (a version is one skill; multiple rows of one
  # boost would double-count in the calculator; e.g. "Dragon-Knight's Might" used to pull
  # every size of the Might family).
  #
  # Size rules: a SIZED skill matches rows of that size or the family's sizeless rows
  # (size-independent curves like Arts) — never a DIFFERENT explicit size. A SIZELESS
  # skill is size-agnostic only when the family is unambiguous (one distinct size per
  # boost, e.g. Sephira/unique modifiers); a multi-size family can't be guessed, so the
  # boost resolves to nothing and the description-extraction track fills (or logs) the
  # gap. Series cascades through SERIES_FALLBACK per boost, preferring the exact series;
  # nil series is series-agnostic. Returns an Array.
  def self.for_skill(modifier:, series: nil, size: nil)
    rows = canonical.where(modifier: modifier)
    rows = rows.where(size: [size, nil]) if size
    compatible = SERIES_FALLBACK.fetch(series, [series])

    rows.group_by(&:boost_type).values.filter_map do |group|
      group = series_matched(group, series, compatible) if series.present?
      next if group.empty?
      next if size.nil? && group.map(&:size).compact.uniq.many? # ambiguous — don't guess

      # Prefer the exact size over sizeless; the exact series over the shared fallback
      # over tolerated drift; then the strongest curve (the old canonical_curve tie-break).
      group.max_by do |d|
        [d.size == size ? 1 : 0, -(compatible.index(d.series) || compatible.size), d.sl15.to_f]
      end
    end
  end

  # Rows a series-bearing skill may use: its own/shared series (or series-less data), else —
  # when the family stores exactly ONE series — tolerate the drift (a single-series family's
  # series is often an import default, not a real frame claim; e.g. Strike's "normal").
  # "normal_omega" IS an explicit frame claim (the Normal/Omega shared curve), so it never
  # crosses to EX/Odious skills.
  def self.series_matched(group, series, compatible)
    matched = group.select { |d| d.series.nil? || compatible.include?(d.series) }
    return matched if matched.any?

    lone = group.map(&:series).uniq
    lone.size == 1 && lone.first != "normal_omega" ? group : []
  end
  private_class_method :series_matched
end

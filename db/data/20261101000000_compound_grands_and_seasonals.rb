# frozen_string_literal: true

# Makes Grand characters and seasonals compound: each further one is worth
# twice the one before (growth_ratio 2), so a single seasonal stays cheap
# while several are a strong signal.
#
# - Seasonal weapons and seasonal characters each become one rule across
#   every season (the Halloween/Valentine/Holiday rules are deactivated and
#   Formal keeps a small per-item bonus), so a Formal and a Summer weapon
#   compound like two of the same season.
# - Seasonals start slightly above Grands at every count (3.5 vs 3 for
#   characters), since they're categorically scarcer; seasonal weapons
#   start at 12 and are the strongest single signal.
# - Grand characters count from one again, up to four.
# - target_max and the Endgame/Whale cutoffs are recomputed at the 99th and
#   80th percentiles of the 2026-10-31 backup under these weights.
#
# `down` restores the 2026-10-31 ruleset.
class CompoundGrandsAndSeasonals < ActiveRecord::Migration[8.1]
  DIR = Rails.root.join('db/data/difficulty_rulesets')

  def up
    apply('20261101.json')
  end

  def down
    apply('20261031.json')
  end

  private

  def apply(file)
    return unless DifficultyComponent.exists? && Difficulty.exists?

    ruleset = PartyDifficulty::Calibration::Ruleset.from_file(DIR.join(file))
    PartyDifficulty::Calibration::Applier.new(ruleset).apply!
  end
end

# frozen_string_literal: true

# Applies the difficulty ruleset calibrated offline against the 2026-10-31
# production backup (see `bin/rails difficulty:calibrate`):
#
# - every component gets a target_max at its 99th-percentile points, so top
#   teams can reach the upper tiers (the live maximum was 49.7 of 100)
# - weapons and characters carry more weight than summons
# - gacha summon uncaps score cumulatively: 3★ (copies) is worth the most,
#   4★ and 5★ add a little, and transcendence adds a lot
# - Grand and gacha weapons count from 3★, multiple Grand characters are
#   needed, seasonal weapons and summons are worth more
# - the Providence/Draconic weapons rule points at a series that exists
# - Mid is renamed Intermediate (the slug stays `mid`), and the tier
#   cutoffs move to 20 / 52 / 84
#
# The previous ruleset is kept next to the new one so `down` restores it.
class CalibrateDifficultyRuleset < ActiveRecord::Migration[8.1]
  DIR = Rails.root.join('db/data/difficulty_rulesets')

  def up
    apply('20261031.json')
  end

  def down
    apply('20261031-before.json')
  end

  private

  def apply(file)
    return unless DifficultyComponent.exists? && Difficulty.exists?

    ruleset = PartyDifficulty::Calibration::Ruleset.from_file(DIR.join(file))
    PartyDifficulty::Calibration::Applier.new(ruleset).apply!
  end
end

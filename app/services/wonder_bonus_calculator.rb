# frozen_string_literal: true

##
# The bonuses a Wonder gives, as `[{ stat:, value: }]` with values as
# percentages (Integer when whole, Float otherwise, for JSON).
#
# - leveled: the per-level additions up to the level, summed by stat, in the
#   order each stat first appears.
# - scaling (Symbolum Amicitiae): DMG Amplify from the character count:
#   +0.5% at 300, +0.5% more at 600, then +0.1% per 10 above 600, up to 5%.
#   Computed in integer tenths so it's exact.
# - fixed: none; their effects are the catalogue's effect lines.
#
# Stat keys: `<el>_resistance`, `<el>_atk`, `dmg_amplify_vs_<el>`, def,
# double_attack_rate, triple_attack_rate, healing_cap, debuff_resistance,
# debuff_success_rate, skill_dmg, ca_dmg, na_dmg_cap, skill_dmg_cap,
# ca_dmg_cap and dmg_amplify.
module WonderBonusCalculator
  SCALING_STAT = 'dmg_amplify'
  # Symbolum character-count thresholds, and its cap in tenths of a percent
  SYMBOLUM_FIRST = 300
  SYMBOLUM_SECOND = 600
  SYMBOLUM_STEP = 10
  SYMBOLUM_MAX_TENTHS = 50

  module_function

  # @param wonder [Wonder] with level_bonuses loaded or loadable
  def for(wonder, level: nil, possession: nil)
    case wonder.kind
    when 'leveled' then leveled(wonder.level_bonuses.to_a, level)
    when 'scaling' then [{ stat: SCALING_STAT, value: from_tenths(symbolum_tenths(possession)) }]
    else []
    end
  end

  # @param rows [Array<WonderLevelBonus>]
  def leveled(rows, level)
    return [] if level.nil?

    totals = {}
    rows.select { |row| row.level <= level.to_i }.sort_by(&:level).each do |row|
      totals[row.stat] = totals.fetch(row.stat, 0) + row.value
    end
    totals.map { |stat, value| { stat: stat, value: value } }
  end

  # Symbolum's DMG Amplify in tenths of a percent for a character count.
  def symbolum_tenths(possession)
    count = possession.to_i
    return 0 if count < SYMBOLUM_FIRST
    return 5 if count < SYMBOLUM_SECOND

    [10 + ((count - SYMBOLUM_SECOND) / SYMBOLUM_STEP), SYMBOLUM_MAX_TENTHS].min
  end

  def from_tenths(tenths)
    (tenths % 10).zero? ? tenths / 10 : tenths / 10.0
  end
end

# frozen_string_literal: true

# Sets summons.subaura on every summon that has sub-aura rows but no flag. The flag is set by
# hand (the wiki has no subaura field), so summons added since the last pass were missed:
# Alphonse Elric, Alex Louis Armstrong, The Supreme Conqueror, Kisuke Urahara and Ms. Tart Man
# on 2026-10-23. Without it the grid refuses them in the sub-aura slots (positions 4-5).
#
# Only turns flags on: a summon flagged without sub-aura rows is left alone. update_all
# writes the column alone, with no callbacks. Rerunnable: flagged rows no longer match.
class FlagSummonsWithSubAuras < ActiveRecord::Migration[8.1]
  def up
    missing = Summon.where(subaura: false)
                    .where(granblue_id: SummonAura.where(slot: 'sub').select(:summon_granblue_id))
    ids = missing.pluck(:granblue_id)
    missing.update_all(subaura: true)
    say "flagged #{ids.size} summons with sub auras: #{ids.join(', ')}"
  end

  def down
    # Nothing to undo: the flag matches the summons' auras.
  end
end

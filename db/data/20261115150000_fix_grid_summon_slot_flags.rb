# frozen_string_literal: true

# Makes the main and friend flags on grid summons follow the slot (GBF-263): -1 is the main
# summon, 6 the friend summon. From February 2025 until #519 the deck import flagged a
# deck's first sub summon (position 4) as main, and remixes copied the flag on. The
# calculator and the aura display read the flag, so those teams counted a sub summon's
# main aura. A few teams also have a main or friend summon without its flag.
#
# GridSummon now sets both flags from the position on every save; this fixes the rows
# already stored. Substitutes keep their flags. The parties' summon boost columns are
# computed from the flags, so the affected parties are recomputed. Rerunnable: each
# update only matches rows whose flag disagrees with the slot.
class FixGridSummonSlotFlags < ActiveRecord::Migration[8.1]
  FRIEND = GridSummon::FRIEND_POSITION

  def up
    grid = GridSummon.where(is_substitute: false)
    wrong_main = grid.where(main: true).where.not(position: -1)
                     .or(grid.where(position: -1).where(main: [false, nil]))
    wrong_friend = grid.where(friend: true).where.not(position: FRIEND)
                       .or(grid.where(position: FRIEND).where(friend: [false, nil]))
    party_ids = wrong_main.or(wrong_friend).distinct.pluck(:party_id)

    cleared = grid.where(main: true).where.not(position: -1).update_all(main: false)
    set = grid.where(position: -1).where(main: [false, nil]).update_all(main: true)
    say "main cleared outside the main slot: #{cleared}; set in the main slot: #{set}"

    cleared = grid.where(friend: true).where.not(position: FRIEND).update_all(friend: false)
    set = grid.where(position: FRIEND).where(friend: [false, nil]).update_all(friend: true)
    say "friend cleared outside the friend slot: #{cleared}; set in the friend slot: #{set}"

    Party.where(id: party_ids).includes(summons: { summon: :summon_series }).find_each do |party|
      party.recompute_boost!
      party.recompute_side!
    end
    say "summon boost recomputed for #{party_ids.size} parties"
  end

  def down
    # Nothing to undo: the flags now match the slots.
  end
end

# frozen_string_literal: true

# Sets every Unite and Fight event's element to the boss's element.
#
# events.element is the boss element, and crews bring the element advantaged
# against it (Event::ADVANTAGE_AGAINST). The old gw_events table stored the
# favored element instead, and the merge into events (20261101120000) copied it
# over, so #40-#83 showed the wrong element everywhere: the Database listed the
# favored element as the boss, and crew pages showed the element favored
# against that.
#
# The boss elements come from the Event History table on gbf.wiki's Unite and
# Fight page, fetched 2026-11-25. Each value is set by event number rather than
# flipped, so the migration is rerunnable and leaves correct rows alone.
class FixUniteAndFightBossElements < ActiveRecord::Migration[8.1]
  BOSS_ELEMENTS = {
    1 => :Dark, 2 => :Fire, 3 => :Wind, 4 => :Earth, 5 => :Dark, 6 => :Water, 7 => :Light, 8 => :Dark,
    9 => :Fire, 10 => :Wind, 11 => :Water, 12 => :Earth, 13 => :Light, 14 => :Wind, 15 => :Dark, 16 => :Light,
    17 => :Water, 18 => :Dark, 19 => :Fire, 20 => :Earth, 21 => :Water, 22 => :Wind, 23 => :Light, 24 => :Fire,
    25 => :Dark, 26 => :Water, 27 => :Earth, 28 => :Wind, 29 => :Fire, 30 => :Light, 31 => :Dark, 32 => :Water,
    33 => :Earth, 34 => :Fire, 35 => :Wind, 36 => :Light, 37 => :Dark, 38 => :Water, 39 => :Earth, 40 => :Fire,
    41 => :Wind, 42 => :Light, 43 => :Dark, 44 => :Earth, 45 => :Water, 46 => :Fire, 47 => :Wind, 48 => :Light,
    49 => :Dark, 50 => :Earth, 51 => :Fire, 52 => :Wind, 53 => :Water, 54 => :Light, 55 => :Dark, 56 => :Fire,
    57 => :Water, 58 => :Wind, 59 => :Earth, 60 => :Light, 61 => :Dark, 62 => :Water, 63 => :Fire, 64 => :Earth,
    65 => :Wind, 66 => :Light, 67 => :Dark, 68 => :Water, 69 => :Earth, 70 => :Fire, 71 => :Wind, 72 => :Dark,
    73 => :Light, 74 => :Water, 75 => :Earth, 76 => :Fire, 77 => :Dark, 78 => :Wind, 79 => :Light, 80 => :Earth,
    81 => :Water, 82 => :Fire, 83 => :Wind, 84 => :Dark, 85 => :Light
  }.freeze

  def up
    fixed = BOSS_ELEMENTS.sum do |number, boss|
      value = GranblueEnums::ELEMENTS.fetch(boss)
      Event.unite_and_fight.where(event_number: number).where('element IS DISTINCT FROM ?', value)
           .update_all(element: value, updated_at: Time.current)
    end
    # update_all skips the callback that clears the cached Home feed
    HomeFeed.expire if fixed.positive?
    say "Unite and Fight boss elements fixed: #{fixed}"
  end

  def down
    # Nothing to undo: the old values were wrong.
  end
end

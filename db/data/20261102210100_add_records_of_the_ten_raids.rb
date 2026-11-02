# frozen_string_literal: true

# Records of the Ten: a solo event that runs once per element, except Fire and
# Dark, which share a run. The bosses aren't named monsters, so one group
# covers every run and teams are matched to the run by element (see
# Event#advantage_elements). Raids are named like Unite and Fight's: by
# difficulty.
#
# The group goes after Dread Barrage, Unite and Fight and the six Exo Crucible
# groups. Raids that already exist are left alone, so editors' changes win.
class AddRecordsOfTheTenRaids < ActiveRecord::Migration[8.1]
  # [slug suffix, level, name en, name jp]
  RAIDS = [
    ['very-hard', 75, 'Very Hard', 'VERY HARD'],
    ['extreme', 80, 'Extreme', 'EXTREME'],
    ['impossible', 95, 'Impossible', 'IMPOSSIBLE'],
    ['nm100', 100, 'NM100', '100HELL'],
    ['nm150', 150, 'NM150', '150HELL']
  ].freeze

  GROUP_ORDER = 9
  EVENTS_SECTION = 2
  SOLO = 1

  def up
    group = RaidGroup.find_or_create_by!(name_en: 'Records of the Ten') do |g|
      g.name_jp = '十天衆イベント'
      g.section = EVENTS_SECTION
      g.order = GROUP_ORDER
      g.difficulty = 1
      g.support_summon = true
    end

    created = RAIDS.count do |suffix, level, name_en, name_jp|
      slug = "rott-#{suffix}"
      next false if Raid.exists?(slug: slug)

      Raid.create!(slug: slug, group: group, name_en: name_en, name_jp: name_jp,
                   level: level, element: 0, player_count: SOLO)
    end
    say "#{created} Records of the Ten raids created"
  end

  def down
    # Nothing to undo: teams may already point at these raids.
  end
end

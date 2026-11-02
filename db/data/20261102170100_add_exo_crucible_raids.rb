# frozen_string_literal: true

# Exo Crucible: a solo event with one boss per run. Each boss's group holds
# Lv80, Lv155, Lv180 and Lv200 (of the stages every 5 levels from 80 to 200)
# and Zenith Domain, the endless challenge mode, which has no level.
#
# The groups exist in production (made in Database); they're created here
# where they don't, so every environment ends up the same. They sit after
# Dread Barrage and Unite and Fight, in element order. Raids that already
# exist are left alone, so editors' changes win.
class AddExoCrucibleRaids < ActiveRecord::Migration[8.1]
  # In element order (GranblueEnums::ELEMENTS): Fire, Water, Earth, Wind, Light, Dark
  BOSSES = [
    { key: 'ifrit', name_en: 'Exo Ifrit', name_jp: 'エクス・イフリート', element: 1 },
    { key: 'cocytus', name_en: 'Exo Cocytus', name_jp: 'エクス・コキュートス', element: 2 },
    { key: 'vohu-manah', name_en: 'Exo Vohu Manah', name_jp: 'エクス・ウォフマナフ', element: 3 },
    { key: 'sagittarius', name_en: 'Exo Sagittarius', name_jp: 'エクス・サジタリウス', element: 4 },
    { key: 'corow', name_en: 'Exo Corow', name_jp: 'エクス・コロゥ', element: 5 },
    { key: 'diablo', name_en: 'Exo Diablo', name_jp: 'エクス・ディアボロス', element: 6 }
  ].freeze

  # The stages we track, as [slug suffix, level, short name en, short name jp]
  STAGES = [
    ['lv80', 80, 'Lv80', 'Lv80'],
    ['lv155', 155, 'Lv155', 'Lv155'],
    ['lv180', 180, 'Lv180', 'Lv180'],
    ['lv200', 200, 'Lv200', 'Lv200'],
    ['zenith', nil, 'Zenith Domain', '廻滅領域']
  ].freeze

  # Dread Barrage is 1 and Unite and Fight 2 in the events section
  FIRST_ORDER = 3
  EVENTS_SECTION = 2
  SOLO = 1

  def up
    created = 0
    BOSSES.each_with_index do |boss, index|
      group = find_or_create_group(boss)
      group.update!(order: FIRST_ORDER + index) unless group.order == FIRST_ORDER + index

      STAGES.each do |suffix, level, short_en, short_jp|
        slug = "exo-#{boss[:key]}-#{suffix}"
        next if Raid.exists?(slug: slug)

        Raid.create!(
          slug: slug,
          group: group,
          name_en: level ? "#{boss[:name_en]} #{short_en}" : "#{boss[:name_en]} Zenith",
          name_jp: "#{boss[:name_jp]} #{short_jp}",
          short_name_en: short_en,
          short_name_jp: short_jp,
          level: level,
          element: boss[:element],
          player_count: SOLO
        )
        created += 1
      end
    end
    say "#{created} Exo Crucible raids created"
  end

  def down
    # Nothing to undo: teams may already point at these raids.
  end

  private

  def find_or_create_group(boss)
    RaidGroup.find_or_create_by!(name_en: "#{boss[:name_en]} Crucible") do |group|
      group.name_jp = "#{boss[:name_jp]}神滅戦"
      group.section = EVENTS_SECTION
      group.order = FIRST_ORDER
      group.difficulty = 1
      group.support_summon = true
    end
  end
end

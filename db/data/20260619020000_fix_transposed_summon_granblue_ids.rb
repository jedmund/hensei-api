# frozen_string_literal: true

# Two R-rarity summons had digit-transposed granblue_ids. Rivacuda's was 2020032000,
# colliding with Purgatorian (whose 2020032000 is correct); Rivacuda's correct id is
# 2020023000 — but that was held by Rodfly, whose own id was also wrong (correct:
# 2020026000). Correct both to the authoritative gbf.wiki / game ids. The collision was
# silently merging the two summons' aura rows on load.
#
# Targeted by name_en because Rivacuda and Purgatorian currently share granblue_id.
# Order matters: free 2020023000 (Rodfly) before reassigning it to Rivacuda.
class FixTransposedSummonGranblueIds < ActiveRecord::Migration[8.0]
  FIXES = [
    ["Rodfly", "2020026000"],   # was 2020023000
    ["Rivacuda", "2020023000"]  # was 2020032000 (collided with Purgatorian)
  ].freeze

  def up
    FIXES.each { |name, gid| Summon.where(name_en: name).update_all(granblue_id: gid) }
  end

  def down
    Summon.where(name_en: "Rivacuda").update_all(granblue_id: "2020032000")
    Summon.where(name_en: "Rodfly").update_all(granblue_id: "2020023000")
  end
end

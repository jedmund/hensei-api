# frozen_string_literal: true

# weapon_series.has_awakening was seeded from a hardcoded five-series list, but
# grand, ennead, and class-champion also contain weapons with weapon_awakenings
# rows (e.g. Fist of Destruction), so the frontend's Edit-weapon pane — which
# gates on the series flag — never offered their awakenings. Sync the flag from
# the data in both directions: a series has awakenings iff one of its weapons
# does. Weapons without awakenings in a flagged series still hide the pane via
# the per-weapon max_awakening_level > 0 check.
#
# Runs after the Taisai reclassification so gacha (whose only awakening-bearing
# weapon was the misclassified Taisai Spirit Bow) correctly stays false.
class SyncWeaponSeriesAwakeningFlags < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE weapon_series ws
      SET has_awakening = EXISTS (
        SELECT 1 FROM weapons w
        JOIN weapon_awakenings wa ON wa.weapon_id = w.id
        WHERE w.weapon_series_id = ws.id
      )
      WHERE ws.has_awakening != EXISTS (
        SELECT 1 FROM weapons w
        JOIN weapon_awakenings wa ON wa.weapon_id = w.id
        WHERE w.weapon_series_id = ws.id
      )
    SQL
  end

  def down
    # Restore the seed's original explicit list.
    execute <<~SQL
      UPDATE weapon_series SET has_awakening = (slug IN ('revans', 'celestial', 'exo', 'proven', 'world'))
    SQL
  end
end

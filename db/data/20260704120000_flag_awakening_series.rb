# frozen_string_literal: true

# The weapon_series seed hardcoded has_awakening for five series, but four more
# (grand, ennead, class-champion, gacha) contain weapons with weapon_awakenings
# rows — e.g. Fist of Destruction (grand) — so the frontend's Edit-weapon pane,
# which gates on the series flag, never offered their awakenings. Derive the flag
# from the data instead of a list: any series containing a weapon with awakening
# rows has awakenings. The per-weapon max_awakening_level > 0 check still hides
# the pane for series-mates without awakenings.
#
# Also: the in-use Exo Heliocentrum row (a known granblue_id-1040424300 duplicate)
# carries the awakening links but a NULL max_awakening_level — copy its twin's 10.
class FlagAwakeningSeries < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE weapon_series ws SET has_awakening = true
      WHERE ws.has_awakening = false AND EXISTS (
        SELECT 1 FROM weapons w
        JOIN weapon_awakenings wa ON wa.weapon_id = w.id
        WHERE w.weapon_series_id = ws.id
      )
    SQL

    execute <<~SQL
      UPDATE weapons SET max_awakening_level = 10
      WHERE granblue_id = '1040424300' AND max_awakening_level IS NULL
    SQL
  end

  def down
    # Restore the seed's original explicit list.
    execute <<~SQL
      UPDATE weapon_series SET has_awakening = (slug IN ('revans', 'celestial', 'exo', 'proven', 'world'))
    SQL
  end
end

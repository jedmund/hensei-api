# frozen_string_literal: true

# Taisai Spirit Bow (1040708700) is a Grand weapon but was imported under the
# generic gacha series. Its weapon_awakenings rows made gacha look like an
# awakening-bearing series to the flag sync that follows.
class ReclassifyTaisaiSpiritBow < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE weapons
      SET weapon_series_id = (SELECT id FROM weapon_series WHERE slug = 'grand')
      WHERE granblue_id = '1040708700'
        AND weapon_series_id = (SELECT id FROM weapon_series WHERE slug = 'gacha')
    SQL
  end

  def down
    execute <<~SQL
      UPDATE weapons
      SET weapon_series_id = (SELECT id FROM weapon_series WHERE slug = 'gacha')
      WHERE granblue_id = '1040708700'
    SQL
  end
end

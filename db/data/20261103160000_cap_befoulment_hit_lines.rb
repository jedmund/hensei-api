# frozen_string_literal: true

# Befoulments stack per stat to a floor the game's panel stops at: ATK, DEF, Turn DMG
# and C.A. DMG Hit at -99%, HP Hit at -90% (h6sAVJ: five C.A. DMG Down copies sum to
# -129, the panel reads -99). A negative grid_cap is a floor (GridDamage::Aggregator).
class CapBefoulmentHitLines < ActiveRecord::Migration[8.1]
  FLOORS = {
    'atk_hit' => ['ATK Hit', 'offensive', -99],
    'ca_dmg_hit' => ['C.A. DMG Hit', 'offensive', -99],
    'def_hit' => ['DEF Hit', 'defensive', -99],
    'turn_dmg_hit' => ['Turn DMG', 'defensive', -99],
    'hp_hit' => ['HP Hit', 'defensive', -90]
  }.freeze

  def up
    FLOORS.each do |key, (name, category, floor)|
      row = WeaponSkillBoostType.find_or_initialize_by(key: key)
      row.update!(name_en: row.name_en.presence || name, category: row.category.presence || category,
                  stacking_rule: row.stacking_rule.presence || 'additive', grid_cap: floor, cap_is_flat: false,
                  notes: "Befoulment line; the panel stops at #{floor}%.")
    end
  end

  def down
    WeaponSkillBoostType.where(key: FLOORS.keys).find_each { |row| row.update!(grid_cap: nil) }
  end
end

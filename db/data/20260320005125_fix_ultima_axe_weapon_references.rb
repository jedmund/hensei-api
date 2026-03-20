# frozen_string_literal: true

class FixUltimaAxeWeaponReferences < ActiveRecord::Migration[7.1]
  def up
    ultima_axe = Weapon.find_by(granblue_id: '1040307800')
    berserkers_barrage = Weapon.find_by(granblue_id: '1040308400')

    return unless ultima_axe && berserkers_barrage

    # Light (6) and Dark (5) Ultima Axe variants were incorrectly mapped
    # to Berserker's Barrage due to a proximity-based ID collision (PR #318)
    affected_elements = [5, 6]

    GridWeapon.where(weapon_id: berserkers_barrage.id, element: affected_elements)
              .update_all(weapon_id: ultima_axe.id)

    CollectionWeapon.where(weapon_id: berserkers_barrage.id, element: affected_elements)
                    .update_all(weapon_id: ultima_axe.id)
  end

  def down
    # Intentionally irreversible — cannot distinguish corrected records from
    # legitimately created Light/Dark Ultima Axe entries after the fact.
  end
end

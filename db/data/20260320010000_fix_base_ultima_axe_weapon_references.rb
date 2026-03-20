# frozen_string_literal: true

class FixBaseUltimaAxeWeaponReferences < ActiveRecord::Migration[7.1]
  def up
    ultima_axe = Weapon.find_by(granblue_id: '1040307800')
    berserkers_barrage = Weapon.find_by(granblue_id: '1040308400')

    return unless ultima_axe && berserkers_barrage

    # Base (null element) Ultima Axe was also mapped to Berserker's Barrage
    # due to the proximity-based ID collision (PR #318)
    GridWeapon.where(weapon_id: berserkers_barrage.id, element: 0)
              .update_all(weapon_id: ultima_axe.id)

    CollectionWeapon.where(weapon_id: berserkers_barrage.id, element: 0)
                    .update_all(weapon_id: ultima_axe.id)
  end

  def down
    # Intentionally irreversible
  end
end

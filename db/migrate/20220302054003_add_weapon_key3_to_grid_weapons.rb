class AddWeaponKey3ToGridWeapons < ActiveRecord::Migration[6.1]
    def change
        add_reference :grid_weapons, :weapon_key3, type: :uuid, foreign_key: { to_table: :weapon_keys }
    end
end

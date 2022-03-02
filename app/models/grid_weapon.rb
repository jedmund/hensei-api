class GridWeapon < ApplicationRecord
    belongs_to :party

    belongs_to :weapon_key1, class_name: 'WeaponKey', foreign_key: :weapon_key1_id
    belongs_to :weapon_key2, class_name: 'WeaponKey', foreign_key: :weapon_key2_id
    belongs_to :weapon_key3, class_name: 'WeaponKey', foreign_key: :weapon_key3_id

    def weapon
        Weapon.find(self.weapon_id)
    end

    def weapon_keys
        weapon_keys = []
        weapon_keys.push(self.weapon_key1) if self.weapon_key1 != nil
        weapon_keys.push(self.weapon_key2) if self.weapon_key2 != nil
        weapon_keys.push(self.weapon_key3) if self.weapon_key3 != nil

        weapon_keys
    end
end

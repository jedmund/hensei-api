class GridWeapon < ApplicationRecord
    belongs_to :party

    def weapon
        Weapon.find(self.weapon_id)
    end
end

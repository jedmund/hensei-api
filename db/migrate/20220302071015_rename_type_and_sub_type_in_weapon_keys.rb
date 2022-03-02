class RenameTypeAndSubTypeInWeaponKeys < ActiveRecord::Migration[6.1]
    def change
        rename_column :weapon_keys, :type, :slot
        rename_column :weapon_keys, :subtype, :group
    end
end

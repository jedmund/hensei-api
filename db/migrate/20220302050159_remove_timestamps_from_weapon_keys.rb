class RemoveTimestampsFromWeaponKeys < ActiveRecord::Migration[6.1]
    def change
        remove_column :weapon_keys, :created_at, :datetime
        remove_column :weapon_keys, :updated_at, :datetime
    end
end

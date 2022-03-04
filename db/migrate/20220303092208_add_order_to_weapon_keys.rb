class AddOrderToWeaponKeys < ActiveRecord::Migration[6.1]
    def change
        add_column :weapon_keys, :order, :integer
    end
end

class ChangeWeaponSeriesToNumber < ActiveRecord::Migration[6.1]
    def change
        change_column :weapons, :series, 'integer USING CAST(element AS integer)'
    end
end

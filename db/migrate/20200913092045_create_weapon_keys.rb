class CreateWeaponKeys < ActiveRecord::Migration[6.0]
    def change
        create_table :weapon_keys do |t|
            t.string :name_en
            t.string :name_jp

            t.integer :series
            t.integer :type
            
            t.timestamps
        end
    end
end

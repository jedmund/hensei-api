class CreateGridWeapons < ActiveRecord::Migration[6.0]
    def change
        create_table :grid_weapons, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
            t.references :party, type: :uuid
            t.references :weapon, type: :uuid
            
            t.references :weapon_key1, class_name: 'WeaponKey', type: :uuid
            t.references :weapon_key2, class_name: 'WeaponKey', type: :uuid

            t.integer :uncap_level
            t.boolean :mainhand
            t.integer :position

            t.timestamps
        end
    end
end

class AddUlbToCharacters < ActiveRecord::Migration[6.1]
    def up
        add_column :characters, :ulb, :boolean, :default => false
        add_column :characters, :max_hp_ulb, :integer
        add_column :characters, :max_atk_ulb, :integer
        change_column_null :characters, :ulb, false
        change_column_null :characters, :flb, false
    end

    def down
        remove_column :characters, :ulb, :boolean
        remove_column :characters, :max_hp_ulb, :integer
        remove_column :characters, :max_atk_ulb, :integer
    end
end

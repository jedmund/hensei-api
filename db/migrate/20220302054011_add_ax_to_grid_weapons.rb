class AddAxToGridWeapons < ActiveRecord::Migration[6.1]
    def change
        add_column :grid_weapons, :ax_modifier1, :integer
        add_column :grid_weapons, :ax_strength1, :float
        add_column :grid_weapons, :ax_modifier2, :integer
        add_column :grid_weapons, :ax_strength2, :float
    end
end

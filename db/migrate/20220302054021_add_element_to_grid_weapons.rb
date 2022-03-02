class AddElementToGridWeapons < ActiveRecord::Migration[6.1]
    def change
        add_column :grid_weapons, :element, :integer
    end
end

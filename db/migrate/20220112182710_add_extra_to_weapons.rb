class AddExtraToWeapons < ActiveRecord::Migration[6.1]
    def change
        add_column :weapons, :extra, :boolean, :default => false, :null => false
    end
end

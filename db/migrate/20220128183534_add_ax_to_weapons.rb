class AddAxToWeapons < ActiveRecord::Migration[6.1]
    def change
        add_column :weapons, :ax, :integer
    end
end

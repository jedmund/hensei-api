class AddWeaponsCountToParties < ActiveRecord::Migration[6.1]
    def change
        add_column :parties, :weapons_count, :integer
    end
end

class AddLimitsToWeapons < ActiveRecord::Migration[6.1]
    def change
        add_column :weapons, :limit, :integer
    end
end

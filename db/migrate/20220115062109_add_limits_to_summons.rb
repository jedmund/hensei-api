class AddLimitsToSummons < ActiveRecord::Migration[6.1]
    def change
        add_column :summons, :limit, :integer
    end
end

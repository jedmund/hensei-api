class RemoveLimitGroupFromWeapons < ActiveRecord::Migration[6.1]
    def change
        remove_column :weapons, :limit_group
    end
end

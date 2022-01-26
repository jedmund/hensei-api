class AddSubauraToSummons < ActiveRecord::Migration[6.1]
    def change
        add_column :summons, :subaura, :boolean, :default => false, :null => false
    end
end

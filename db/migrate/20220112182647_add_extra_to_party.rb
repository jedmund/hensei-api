class AddExtraToParty < ActiveRecord::Migration[6.1]
    def change
        add_column :parties, :extra, :boolean, :default => false, :null => false
    end
end

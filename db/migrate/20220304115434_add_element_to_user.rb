class AddElementToUser < ActiveRecord::Migration[6.1]
    def change
        add_column :users, :element, :string, :default => "water", :null => false
    end
end

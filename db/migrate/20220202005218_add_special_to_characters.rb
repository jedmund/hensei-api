class AddSpecialToCharacters < ActiveRecord::Migration[6.1]
    def up
        add_column :characters, :special, :boolean, :default => false
        change_column_null :characters, :special, false
    end
    
    def down
        remove_column :characters, :special, :boolean
    end
end

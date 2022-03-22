class AddDefaultsToCharacters < ActiveRecord::Migration[6.1]
    def up
        change_column :characters, :flb, :boolean, default: false, null: false
    end

    def down

    end
end

class AddForeignKeyRelationsToObjects < ActiveRecord::Migration[6.1]
    def change
        add_foreign_key :grid_characters, :parties
        add_foreign_key :grid_characters, :characters

        add_foreign_key :grid_weapons, :parties
        add_foreign_key :grid_weapons, :weapons

        add_foreign_key :grid_summons, :parties
        add_foreign_key :grid_summons, :summons
    end
end

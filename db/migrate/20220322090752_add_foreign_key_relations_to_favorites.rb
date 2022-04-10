class AddForeignKeyRelationsToFavorites < ActiveRecord::Migration[6.1]
    def change
        add_foreign_key :favorites, :users
        add_foreign_key :favorites, :parties
    end
end

class AddForeignKeyRelationsToParties < ActiveRecord::Migration[6.1]
    def change
        add_foreign_key :parties, :users
        add_foreign_key :parties, :raids
    end
end

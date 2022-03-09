class AddGinIndexToSummonsAndCharacters < ActiveRecord::Migration[6.1]
    def change
        add_index :summons, :name_en, using: :gin, opclass: :gin_trgm_ops
        add_index :characters, :name_en, using: :gin, opclass: :gin_trgm_ops
    end
end

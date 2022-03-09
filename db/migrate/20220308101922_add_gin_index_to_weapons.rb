class AddGinIndexToWeapons < ActiveRecord::Migration[6.1]
    def change
        enable_extension "pg_trgm"
        enable_extension "btree_gin"
        add_index :weapons, :name_en, using: :gin, opclass: :gin_trgm_ops
    end
end

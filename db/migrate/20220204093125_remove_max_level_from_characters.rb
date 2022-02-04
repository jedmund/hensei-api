class RemoveMaxLevelFromCharacters < ActiveRecord::Migration[6.1]
    def change
        remove_column :characters, :max_level, :boolean
    end
end

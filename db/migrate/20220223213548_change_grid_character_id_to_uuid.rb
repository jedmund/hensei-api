class ChangeGridCharacterIdToUuid < ActiveRecord::Migration[6.1]
    def change
        change_table :grid_characters do |t|
            t.remove :id
            t.rename :uuid, :id
        end
  
        execute "ALTER TABLE grid_characters ADD PRIMARY KEY (id);"
    end
end

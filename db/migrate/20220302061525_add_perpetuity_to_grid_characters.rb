class AddPerpetuityToGridCharacters < ActiveRecord::Migration[6.1]
    def change
        add_column :grid_characters, :perpetuity, :boolean
    end
end

class AddUuidToGridCharacter < ActiveRecord::Migration[6.1]
    def change
        add_column :grid_characters, :uuid, :uuid, default: "gen_random_uuid()", null: false
    end
end

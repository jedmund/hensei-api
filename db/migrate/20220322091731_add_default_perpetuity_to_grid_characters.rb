class AddDefaultPerpetuityToGridCharacters < ActiveRecord::Migration[6.1]
    def up
        GridCharacter.find_each do |char|
            char.perpetuity = false
            char.save!
        end

        change_column :grid_characters, :perpetuity, :boolean, default: false, null: false
    end

    def down

    end
end

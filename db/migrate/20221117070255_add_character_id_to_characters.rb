class AddCharacterIdToCharacters < ActiveRecord::Migration[6.1]
  def change
    add_column :characters, :character_id, :integer, array: true, null: false, default: []
  end
end

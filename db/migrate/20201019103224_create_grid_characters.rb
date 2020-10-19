class CreateGridCharacters < ActiveRecord::Migration[6.0]
  def change
    create_table :grid_characters do |t|
      t.references :party, type: :uuid
      t.references :character, type: :uuid

      t.integer :uncap_level
      t.integer :position

      t.timestamps
    end
  end
end

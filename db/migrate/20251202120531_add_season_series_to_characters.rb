class AddSeasonSeriesToCharacters < ActiveRecord::Migration[8.0]
  def change
    add_column :characters, :season, :integer, null: true
    add_column :characters, :series, :integer, array: true, default: [], null: false
    add_column :characters, :gacha_available, :boolean, default: true, null: false

    add_index :characters, :season
    add_index :characters, :series, using: :gin
    add_index :characters, :gacha_available
  end
end

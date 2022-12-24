class AddAwakeningToGridCharacters < ActiveRecord::Migration[6.1]
  def change
    add_column :grid_characters, :awakening_type, :integer, null: false, default: 0
    add_column :grid_characters, :awakening_level, :integer, null: false, default: 1
  end
end

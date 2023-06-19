class AddNewAwakeningIdToGridCharacters < ActiveRecord::Migration[7.0]
  def change
    add_reference :grid_characters, :awakening, type: :uuid, foreign_key: { to_table: :awakenings }
    add_column :grid_characters, :awakening_level, :integer, default: 1
  end
end

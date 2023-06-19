class RemoveAwakeningFromGridCharacters < ActiveRecord::Migration[7.0]
  def change
    remove_column :grid_characters, :awakening, :jsonb
  end
end

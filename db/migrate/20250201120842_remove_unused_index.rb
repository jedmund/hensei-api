class RemoveUnusedIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :parties, :visibility
  end
end

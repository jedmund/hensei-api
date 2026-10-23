class RemoveColorFromDifficulties < ActiveRecord::Migration[8.0]
  def change
    remove_column :difficulties, :color, :string
  end
end

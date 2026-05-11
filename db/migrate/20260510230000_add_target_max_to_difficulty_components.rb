class AddTargetMaxToDifficultyComponents < ActiveRecord::Migration[8.0]
  def change
    add_column :difficulty_components, :target_max, :decimal, precision: 8, scale: 2
  end
end

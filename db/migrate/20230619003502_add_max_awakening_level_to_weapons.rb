class AddMaxAwakeningLevelToWeapons < ActiveRecord::Migration[7.0]
  def change
    add_column :weapons, :max_awakening_level, :integer
  end
end

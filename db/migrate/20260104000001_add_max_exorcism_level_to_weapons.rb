class AddMaxExorcismLevelToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :max_exorcism_level, :integer, default: nil
  end
end

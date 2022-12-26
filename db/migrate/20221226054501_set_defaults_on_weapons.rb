class SetDefaultsOnWeapons < ActiveRecord::Migration[6.1]
  def change
    change_column :weapons, :max_level, :integer, null: false, default: 100
    change_column :weapons, :max_skill_level, :integer, null: false, default: 10
  end
end

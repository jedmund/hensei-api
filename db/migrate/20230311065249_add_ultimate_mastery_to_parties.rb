class AddUltimateMasteryToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :ultimate_mastery, :integer
    rename_column :parties, :ml, :master_level
    add_column :jobs, :ultimate_mastery, :boolean, default: false, null: false
    rename_column :jobs, :ml, :master_level
    change_column_null :jobs, :master_level, false
  end
end

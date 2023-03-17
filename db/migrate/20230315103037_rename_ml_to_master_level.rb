class RenameMlToMasterLevel < ActiveRecord::Migration[7.0]
  def change
    rename_column :parties, :ml, :master_level
    rename_column :jobs, :ml, :master_level
    change_column_null :jobs, :master_level, false
  end
end

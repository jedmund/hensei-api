class RenameLimit2OnSummons < ActiveRecord::Migration[6.1]
  def change
    rename_column :summons, :limit2, :limit
  end
end

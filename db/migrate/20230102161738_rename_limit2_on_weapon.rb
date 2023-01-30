class RenameLimit2OnWeapon < ActiveRecord::Migration[6.1]
  def change
    rename_column :weapons, :limit2, :limit
  end
end

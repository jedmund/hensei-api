class RenameAxToAxTypeOnWeapons < ActiveRecord::Migration[6.1]
  def change
    rename_column :weapons, :ax, :ax_type
  end
end

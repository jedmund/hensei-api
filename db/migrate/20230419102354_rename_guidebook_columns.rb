class RenameGuidebookColumns < ActiveRecord::Migration[7.0]
  def change
    rename_column :parties, :guidebook0_id, :guidebook3_id
  end
end

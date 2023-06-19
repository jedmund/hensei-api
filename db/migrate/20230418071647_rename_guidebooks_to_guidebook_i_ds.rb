class RenameGuidebooksToGuidebookIDs < ActiveRecord::Migration[7.0]
  def change
    rename_column :parties, :guidebooks, :guidebook_ids
  end
end

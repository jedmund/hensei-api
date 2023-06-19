class UpdateGuidebooksStructure < ActiveRecord::Migration[7.0]
  def change
    remove_column :guidebooks, :updated_at
    change_column_default :guidebooks, :created_at, -> { 'CURRENT_TIMESTAMP' }
  end
end

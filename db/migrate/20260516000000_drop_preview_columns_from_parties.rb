class DropPreviewColumnsFromParties < ActiveRecord::Migration[8.0]
  def change
    remove_index :parties, name: 'index_parties_on_preview_generated_at', if_exists: true
    remove_index :parties, name: 'index_parties_on_preview_state', if_exists: true

    remove_column :parties, :preview_state, :integer, default: 0, null: false
    remove_column :parties, :preview_generated_at, :datetime
    remove_column :parties, :preview_s3_key, :string
  end
end

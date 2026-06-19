class DropPreviewColumnsFromParties < ActiveRecord::Migration[8.0]
  def change
    remove_column :parties, :preview_state, :integer, default: 0, null: false
    remove_column :parties, :preview_generated_at, :datetime
    remove_column :parties, :preview_s3_key, :string
  end
end

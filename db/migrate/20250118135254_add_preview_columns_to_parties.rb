class AddPreviewColumnsToParties < ActiveRecord::Migration[8.0]
  def change
    add_column :parties, :preview_state, :integer, default: 0, null: false
    add_column :parties, :preview_generated_at, :datetime

    add_index :parties, :preview_state
    add_index :parties, :preview_generated_at
  end
end

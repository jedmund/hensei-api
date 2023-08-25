class AddVisibilityToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :visibility, :integer, default: 1, null: false
  end
end

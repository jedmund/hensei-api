class AddEditKeyToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :edit_key, :string, unique: true, null: true
  end
end

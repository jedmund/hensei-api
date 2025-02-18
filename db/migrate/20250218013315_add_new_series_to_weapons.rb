class AddNewSeriesToWeapons < ActiveRecord::Migration[8.0]
  def change
    add_column :weapons, :new_series, :integer
  end
end

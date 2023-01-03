class AddBooleanAxToWeapons < ActiveRecord::Migration[6.1]
  def change
    add_column :weapons, :ax, :boolean
  end
end

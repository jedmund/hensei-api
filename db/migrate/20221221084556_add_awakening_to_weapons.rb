class AddAwakeningToWeapons < ActiveRecord::Migration[6.1]
  def change
    add_column :weapons, :awakening, :boolean, null: false, default: true
  end
end

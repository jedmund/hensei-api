class ChangeAxAxTypeProperties < ActiveRecord::Migration[6.1]
  def change
    change_column :weapons, :ax, :boolean, null: false, default: false
    change_column :weapons, :ax_type, :integer, null: true, default: nil
  end
end

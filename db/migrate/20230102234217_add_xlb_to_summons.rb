class AddXlbToSummons < ActiveRecord::Migration[6.1]
  def change
    add_column :summons, :xlb, :boolean, default: false, null: false
  end
end

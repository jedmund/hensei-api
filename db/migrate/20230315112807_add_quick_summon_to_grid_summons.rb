class AddQuickSummonToGridSummons < ActiveRecord::Migration[7.0]
  def change
    add_column :grid_summons, :quick_summon, :boolean, default: false, null: false
  end
end

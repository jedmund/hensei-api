class ReAddQuickSummonAndAutoSummonToGridSummonsAndParties < ActiveRecord::Migration[7.0]
  def change
    add_column :grid_summons, :quick_summon, :boolean, default: false, if_not_exists: true
    add_column :parties, :auto_summon, :boolean, default: false, if_not_exists: true
  end
end

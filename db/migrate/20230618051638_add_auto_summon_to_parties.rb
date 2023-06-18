class AddAutoSummonToParties < ActiveRecord::Migration[7.0]
  def change
    add_column :parties, :auto_summon, :boolean, default: false, null: false
  end
end

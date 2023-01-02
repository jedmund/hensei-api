class AddTranscendenceStepToGridSummons < ActiveRecord::Migration[6.1]
  def change
    add_column :grid_summons, :transcendence_step, :integer, default: 0, null: false
  end
end

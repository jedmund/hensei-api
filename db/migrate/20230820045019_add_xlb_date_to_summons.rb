class AddXlbDateToSummons < ActiveRecord::Migration[7.0]
  def change
    add_column :summons, :xlb_date, :date
  end
end

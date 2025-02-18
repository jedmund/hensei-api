class MoveNewSeriesToSeries < ActiveRecord::Migration[8.0]
  def change
    remove_column :weapons, :series
    rename_column :weapons, :new_series, :series
  end
end

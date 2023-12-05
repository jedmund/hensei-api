class RenameNewSeriesAndDeleteSeries < ActiveRecord::Migration[7.0]
  def change
    remove_column :weapon_keys, :series, :integer
    rename_column :weapon_keys, :new_series, :series
  end
end

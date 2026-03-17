# frozen_string_literal: true

class RemoveLegacySeriesFromWeapons < ActiveRecord::Migration[8.0]
  def change
    remove_column :weapons, :series, :integer
  end
end

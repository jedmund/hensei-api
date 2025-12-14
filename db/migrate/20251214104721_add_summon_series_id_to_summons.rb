# frozen_string_literal: true

class AddSummonSeriesIdToSummons < ActiveRecord::Migration[8.0]
  def change
    add_column :summons, :summon_series_id, :uuid
    add_index :summons, :summon_series_id
    add_foreign_key :summons, :summon_series
  end
end

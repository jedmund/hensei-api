# frozen_string_literal: true

class AddVideoUrlAndSummonCountToParties < ActiveRecord::Migration[8.0]
  def change
    add_column :parties, :video_url, :string, limit: 2048
    add_column :parties, :summon_count, :integer
  end
end

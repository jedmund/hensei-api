# frozen_string_literal: true

class ChangeGwEventsNameNullable < ActiveRecord::Migration[8.0]
  def change
    remove_column :gw_events, :name, :string
  end
end

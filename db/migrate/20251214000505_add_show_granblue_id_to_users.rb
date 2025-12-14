# frozen_string_literal: true

class AddShowGranblueIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :show_granblue_id, :boolean, default: false, null: false
  end
end

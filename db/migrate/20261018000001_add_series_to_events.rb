# frozen_string_literal: true

# Recurring events (Unite and Fight, Dread Barrage, Rise of the Beasts,
# Records of the Ten) share one banner per series; `series` names it.
class AddSeriesToEvents < ActiveRecord::Migration[8.1]
  def change
    add_column :events, :series, :string
    add_index :events, :series
  end
end

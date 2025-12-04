# frozen_string_literal: true

class CreateGwEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :gw_events, id: :uuid do |t|
      t.string :name, null: false
      t.integer :element, null: false
      t.date :start_date, null: false
      t.date :end_date, null: false
      t.integer :event_number, null: false

      t.timestamps
    end

    add_index :gw_events, :event_number, unique: true
    add_index :gw_events, :start_date
  end
end

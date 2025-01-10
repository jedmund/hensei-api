# frozen_string_literal: true

class CreateGranblueDataVersion < ActiveRecord::Migration[7.0]
  def change
    create_table :granblue_data_version do |t|
      t.string :filename, null: false
      t.datetime :imported_at, null: false

      t.timestamps

      t.index :filename, unique: true
    end
  end
end

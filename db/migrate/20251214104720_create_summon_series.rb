# frozen_string_literal: true

class CreateSummonSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :summon_series, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp, null: false
      t.string :slug, null: false
      t.integer :order, default: 0, null: false
    end

    add_index :summon_series, :slug, unique: true
    add_index :summon_series, :order
  end
end

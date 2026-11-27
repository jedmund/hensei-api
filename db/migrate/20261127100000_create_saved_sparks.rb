# frozen_string_literal: true

# Sparks a user saved from the spark maker: the SSRs they pulled on the way to
# a spark, in order. Named saved_sparks because the database already has an
# unrelated legacy `sparks` table (Discord-keyed spark progress).
class CreateSavedSparks < ActiveRecord::Migration[8.1]
  def change
    create_table :saved_sparks, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.date :spark_date, null: false
      t.integer :draws, null: false, default: 300
      # The gacha it was on, both optional: the pool, and its season
      t.string :pool
      t.string :season
      # Catalogue granblue_ids, in display order
      t.string :characters, array: true, null: false, default: []
      t.string :moons, array: true, null: false, default: []
      t.string :summons, array: true, null: false, default: []
      # The item that was sparked rather than drawn, if any
      t.string :sparked_column
      t.integer :sparked_index
      t.timestamps
    end

    add_index :saved_sparks, %i[user_id spark_date]
  end
end

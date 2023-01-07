class MakeMasteryColumnsNotNullable < ActiveRecord::Migration[7.0]
  def change
    change_column :grid_characters, :ring1, :jsonb, null: false
    change_column :grid_characters, :ring2, :jsonb, null: false
    change_column :grid_characters, :ring3, :jsonb, null: false
    change_column :grid_characters, :ring4, :jsonb, null: false
    change_column :grid_characters, :earring, :jsonb, null: false
    change_column :grid_characters, :awakening, :jsonb, null: false
  end
end

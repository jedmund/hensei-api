# frozen_string_literal: true

class CreateArtifacts < ActiveRecord::Migration[8.0]
  def change
    create_table :artifacts, id: :uuid do |t|
      t.string :granblue_id, null: false
      t.string :name_en, null: false
      t.string :name_jp
      t.integer :proficiency
      t.integer :rarity, null: false, default: 0
      t.date :release_date

      # No timestamps - static reference data
    end

    add_index :artifacts, :granblue_id, unique: true
    add_index :artifacts, :proficiency
    add_index :artifacts, :rarity
  end
end

# frozen_string_literal: true

class CreateGridArtifacts < ActiveRecord::Migration[8.0]
  def change
    create_table :grid_artifacts, id: :uuid do |t|
      # One artifact per character - unique index created by references
      t.references :grid_character, type: :uuid, null: false, foreign_key: true, index: { unique: true }
      t.references :artifact, type: :uuid, null: false, foreign_key: true

      t.integer :element, null: false
      t.integer :proficiency  # Only for quirk artifacts (random proficiency assigned by game)
      t.integer :level, null: false, default: 1

      # Skills (JSONB) - each contains: { modifier: int, strength: value, level: int }
      t.jsonb :skill1, default: {}, null: false
      t.jsonb :skill2, default: {}, null: false
      t.jsonb :skill3, default: {}, null: false
      t.jsonb :skill4, default: {}, null: false

      t.timestamps
    end
  end
end

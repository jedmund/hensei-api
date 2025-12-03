# frozen_string_literal: true

class CreateCollectionArtifacts < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_artifacts, id: :uuid do |t|
      t.references :user, type: :uuid, null: false, foreign_key: true
      t.references :artifact, type: :uuid, null: false, foreign_key: true

      t.integer :element, null: false
      t.integer :proficiency  # Only for quirk artifacts (random proficiency assigned by game)
      t.integer :level, null: false, default: 1
      t.string :nickname

      # Skills (JSONB) - each contains: { modifier: int, strength: value, level: int }
      t.jsonb :skill1, default: {}, null: false
      t.jsonb :skill2, default: {}, null: false
      t.jsonb :skill3, default: {}, null: false
      t.jsonb :skill4, default: {}, null: false

      t.timestamps
    end

    add_index :collection_artifacts, [:user_id, :artifact_id]
    add_index :collection_artifacts, :element
  end
end

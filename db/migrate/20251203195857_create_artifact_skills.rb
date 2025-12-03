# frozen_string_literal: true

class CreateArtifactSkills < ActiveRecord::Migration[8.0]
  def change
    create_table :artifact_skills, id: :uuid do |t|
      t.integer :skill_group, null: false  # 1, 2, or 3
      t.integer :modifier, null: false     # Skill ID within the group

      t.string :name_en, null: false
      t.string :name_jp, null: false

      t.jsonb :base_values, null: false, default: []
      t.decimal :growth, precision: 15, scale: 2
      t.string :suffix_en, default: ''
      t.string :suffix_jp, default: ''
      t.string :polarity, null: false, default: 'positive'

      # No timestamps - static reference data
    end

    add_index :artifact_skills, [:skill_group, :modifier], unique: true
    add_index :artifact_skills, :skill_group
  end
end

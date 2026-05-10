class AddDifficultyColumnsToParties < ActiveRecord::Migration[8.0]
  def change
    add_reference :parties, :difficulty, type: :uuid, null: true, foreign_key: true
    add_column :parties, :difficulty_score, :decimal, precision: 5, scale: 2
    add_column :parties, :difficulty_breakdown, :jsonb
    add_column :parties, :difficulty_computed_at, :datetime
    add_column :parties, :difficulty_ruleset_version, :integer

    add_index :parties, :difficulty_score
    add_index :parties, :difficulty_computed_at
  end
end

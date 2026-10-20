# frozen_string_literal: true

# Cached ranking score outside events (Rising, explore sort). Never exposed in
# responses. Indexed like the difficulty columns.
class AddParticipationScoreToParties < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_column :parties, :participation_score, :decimal, precision: 12, scale: 4
    add_column :parties, :participation_computed_at, :datetime

    add_index :parties, :participation_score, algorithm: :concurrently
    add_index :parties, :participation_computed_at, algorithm: :concurrently
  end
end

# frozen_string_literal: true

class CreateGwIndividualScores < ActiveRecord::Migration[8.0]
  def change
    create_table :gw_individual_scores, id: :uuid do |t|
      t.references :crew_gw_participation, type: :uuid, null: false, foreign_key: true
      t.references :crew_membership, type: :uuid, null: true, foreign_key: true
      t.integer :round, null: false
      t.bigint :score, default: 0, null: false
      t.boolean :is_cumulative, default: false, null: false
      t.references :recorded_by, type: :uuid, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :gw_individual_scores, %i[crew_gw_participation_id crew_membership_id round],
              unique: true,
              name: 'idx_gw_individual_scores_unique'
  end
end

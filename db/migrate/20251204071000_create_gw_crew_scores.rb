# frozen_string_literal: true

class CreateGwCrewScores < ActiveRecord::Migration[8.0]
  def change
    create_table :gw_crew_scores, id: :uuid do |t|
      t.references :crew_gw_participation, type: :uuid, null: false, foreign_key: true
      t.integer :round, null: false, comment: '0=prelims, 1=interlude, 2-5=finals day 1-4'
      t.bigint :crew_score, default: 0, null: false
      t.bigint :opponent_score
      t.string :opponent_name
      t.string :opponent_granblue_id
      t.boolean :victory

      t.timestamps
    end

    add_index :gw_crew_scores, %i[crew_gw_participation_id round], unique: true
  end
end

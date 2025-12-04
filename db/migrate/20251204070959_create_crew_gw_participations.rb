# frozen_string_literal: true

class CreateCrewGwParticipations < ActiveRecord::Migration[8.0]
  def change
    create_table :crew_gw_participations, id: :uuid do |t|
      t.references :crew, type: :uuid, null: false, foreign_key: true
      t.references :gw_event, type: :uuid, null: false, foreign_key: true
      t.bigint :preliminary_ranking
      t.bigint :final_ranking

      t.timestamps
    end

    add_index :crew_gw_participations, %i[crew_id gw_event_id], unique: true
  end
end

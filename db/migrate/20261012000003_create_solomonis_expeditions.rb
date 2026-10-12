# frozen_string_literal: true

# One row per Evoking Solomonis party: a build (starting party) or a run (a
# finished expedition). user_id is copied from the party so an imported game
# report can be unique per user.
class CreateSolomonisExpeditions < ActiveRecord::Migration[8.1]
  def change
    create_table :solomonis_expeditions, id: :uuid do |t|
      t.references :party, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.references :user, type: :uuid, foreign_key: { on_delete: :nullify }
      t.string :kind, null: false
      t.references :route_evoker, type: :uuid, null: false, foreign_key: { to_table: :characters }
      t.integer :pledge_level, null: false, default: 0
      t.string :outcome
      t.integer :bosses_defeated
      t.string :midboss
      t.integer :expedition_level
      t.references :build_party, type: :uuid, foreign_key: { to_table: :parties, on_delete: :nullify }
      t.bigint :game_report_id
      t.datetime :ended_at
      t.jsonb :stats, null: false, default: {}
      t.timestamps

      t.index %i[user_id game_report_id], unique: true,
                                          where: 'user_id IS NOT NULL AND game_report_id IS NOT NULL',
                                          name: 'index_solomonis_expeditions_on_user_and_game_report'
      t.index :kind
      t.index :pledge_level
    end
  end
end

class AddGachaRateupsTable < ActiveRecord::Migration[7.0]
  create_table :gacha_rateups, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
    t.references :gacha, type: :uuid
    t.string :user_id
    t.numeric :rate
    t.datetime :created_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end

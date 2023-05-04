class AddSparksTable < ActiveRecord::Migration[7.0]
  create_table :sparks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
    t.string :user_id, null: false
    t.string :guild_ids, array: true, null: false
    t.integer :crystals, default: 0
    t.integer :tickets, default: 0
    t.integer :ten_tickets, default: 0
    t.references :target, polymorphic: true
    t.datetime :updated_at, null: false, default: -> { 'CURRENT_TIMESTAMP' }
  end
end

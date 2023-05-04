class AddGachaTable < ActiveRecord::Migration[7.0]
  create_table :gacha, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
    t.references :drawable, polymorphic: true
    t.boolean :premium
    t.boolean :classic
    t.boolean :flash
    t.boolean :legend
    t.boolean :valentines
    t.boolean :summer
    t.boolean :halloween
    t.boolean :holiday
  end
end

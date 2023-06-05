class AddRaidGroupsTable < ActiveRecord::Migration[7.0]
  create_table :raid_groups, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
    t.string :name_en, null: false
    t.string :name_jp, null: false
    t.integer :difficulty
    t.integer :order, null: false
    t.integer :section, default: 1, null: false
    t.boolean :extra, default: false, null: false
  end
end

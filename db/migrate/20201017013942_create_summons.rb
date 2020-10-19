class CreateSummons < ActiveRecord::Migration[6.0]
  def change
      create_table :summons, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
          t.string :name_en
          t.string :name_jp
          t.integer :granblue_id

          t.integer :rarity
          t.integer :element
          t.string :series

          t.boolean :flb
          t.boolean :ulb

          t.integer :max_level
          t.integer :min_hp
          t.integer :max_hp
          t.integer :max_hp_flb
          t.integer :max_hp_ulb
          t.integer :min_atk
          t.integer :max_atk
          t.integer :max_atk_flb
          t.integer :max_atk_ulb
      end
  end
end

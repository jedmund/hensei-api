class CreateCharacters < ActiveRecord::Migration[6.0]
  def change
    create_table :characters, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
        t.string :name_en
        t.string :name_jp
        t.integer :granblue_id

        t.integer :rarity
        t.integer :element
        t.integer :proficiency1
        t.integer :proficiency2
        t.integer :gender
        t.integer :race1
        t.integer :race2

        t.boolean :flb
        t.boolean :max_level

        t.integer :min_hp
        t.integer :max_hp
        t.integer :max_hp_flb
        t.integer :min_atk
        t.integer :max_atk
        t.integer :max_atk_flb

        t.integer :base_da
        t.integer :base_ta
        t.float :ougi_ratio
        t.float :ougi_ratio_flb
    end
  end
end

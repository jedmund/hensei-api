class CreateSummonAuras < ActiveRecord::Migration[8.0]
  def change
    create_table :summon_auras, id: :uuid do |t|
      t.string :summon_granblue_id, null: false
      t.text :description_en
      t.text :description_jp
      t.integer :aura_type # 1=main, 2=sub
      t.integer :boost_type # 1=weapon skill, 2=elemental, 3=stat
      t.string :boost_target # what is being boosted
      t.decimal :boost_value # percentage value
      t.integer :uncap_level # 0, 3, 4, 5 for uncap level
      t.text :condition # any conditions
      t.timestamps null: false
    end
    add_index :summon_auras, %i[summon_granblue_id aura_type uncap_level]
    add_index :summon_auras, :summon_granblue_id
  end
end

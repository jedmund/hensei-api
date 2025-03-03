class CreateEffects < ActiveRecord::Migration[8.0]
  def change
    create_table :effects, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp
      t.text :description_en
      t.text :description_jp
      t.string :icon_path
      t.integer :effect_type, null: false # 1=buff, 2=debuff, 3=special
      t.string :effect_class # classification (cant_act, burn, poison)
      t.uuid :effect_family_id # no foreign key here
      t.boolean :stackable, default: false
      t.timestamps null: false
    end

    add_foreign_key :effects, :effects, column: :effect_family_id

    add_index :effects, :effect_class
    add_index :effects, :name_en
  end
end

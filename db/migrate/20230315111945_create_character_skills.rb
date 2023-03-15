class CreateCharacterSkills < ActiveRecord::Migration[7.0]
  def change
    create_table :character_skills, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :character, type: :uuid

      t.string :name_en, unique: true, null: false
      t.string :name_jp, unique: true, null: false

      t.string :description_en, unique: true, null: false
      t.string :description_jp, unique: true, null: false

      t.integer :type, null: false
      t.integer :position, null: false

      t.string :form
      t.integer :cooldown, default: 0, null: false
      t.integer :lockout, default: 0, null: false
      t.integer :duration, array: true
      t.boolean :recast, default: false, null: false
      t.integer :obtained_at, default: 1, null: false

      t.uuid :effects, array: true
    end
  end
end

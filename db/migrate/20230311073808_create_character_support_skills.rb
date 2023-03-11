class CreateCharacterSupportSkills < ActiveRecord::Migration[7.0]
  def change
    create_table :character_support_skills, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :character, type: :uuid

      t.string :name_en, unique: true, null: false
      t.string :name_jp, unique: true, null: false

      t.string :description_en, unique: true, null: false
      t.string :description_jp, unique: true, null: false

      t.integer :position, null: false
      t.integer :obtained_at

      t.boolean :emp, default: false, null: false
      t.boolean :transcendence, default: false, null: false

      t.uuid :effects, array: true
    end
  end
end

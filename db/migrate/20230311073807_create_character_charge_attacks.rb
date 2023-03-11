class CreateCharacterChargeAttacks < ActiveRecord::Migration[7.0]
  def change
    create_table :character_charge_attacks, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.references :character, type: :uuid

      t.string :name_en, unique: true, null: false
      t.string :name_jp, unique: true, null: false

      t.string :description_en, unique: true, null: false
      t.string :description_jp, unique: true, null: false

      t.integer :order, null: false
      t.string :form

      t.uuid :effects, array: true
    end
  end
end

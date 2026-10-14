# frozen_string_literal: true

# Arcarum Blessings for Evoking Solomonis: the catalogue, its levels, and the
# loadout each party equips (at most one level of each blessing).
class CreateArcarumBlessings < ActiveRecord::Migration[8.1]
  def change
    create_table :arcarum_blessings, id: :uuid do |t|
      t.string :slug, null: false
      t.integer :arcana_number, null: false
      t.string :name_en
      t.string :name_jp
      t.boolean :released, null: false, default: false
      t.timestamps
      t.index :slug, unique: true
      t.index :arcana_number, unique: true
    end

    create_table :arcarum_blessing_levels, id: :uuid do |t|
      t.references :arcarum_blessing, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.integer :level, null: false
      t.text :description_en
      t.text :description_jp
      t.integer :cost, null: false
      t.integer :scintillas
      t.timestamps
      t.index %i[arcarum_blessing_id level], unique: true
    end

    create_table :party_blessings, id: :uuid do |t|
      t.references :party, type: :uuid, null: false, foreign_key: { on_delete: :cascade }, index: false
      t.references :arcarum_blessing, type: :uuid, null: false, foreign_key: true
      t.references :arcarum_blessing_level, type: :uuid, null: false, foreign_key: true
      t.timestamps
      t.index %i[party_id arcarum_blessing_id], unique: true
    end
  end
end

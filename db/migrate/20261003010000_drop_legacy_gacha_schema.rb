# frozen_string_literal: true

# Gacha pools live in weapons.promotions and summons.promotions, and saved
# rate-ups use their typed drawable reference. The legacy gacha table, the
# rate-up link to it and the unused weapons.gacha flag are no longer read.
class DropLegacyGachaSchema < ActiveRecord::Migration[8.0]
  def up
    remove_column :gacha_rateups, :gacha_id
    drop_table :gacha
    remove_column :weapons, :gacha
    change_column_null :gacha_rateups, :drawable_type, false
    change_column_null :gacha_rateups, :drawable_id, false
  end

  # Restores the structure only; dropped rows and flags are not recovered.
  def down
    change_column_null :gacha_rateups, :drawable_id, true
    change_column_null :gacha_rateups, :drawable_type, true
    add_column :weapons, :gacha, :boolean, default: false, null: false
    add_index :weapons, :gacha
    create_table :gacha, id: :uuid do |t|
      t.boolean :premium
      t.boolean :classic
      t.boolean :flash
      t.boolean :legend
      t.boolean :valentines
      t.boolean :summer
      t.boolean :halloween
      t.boolean :holiday
      t.string :drawable_type
      t.uuid :drawable_id
      t.boolean :classic_ii, default: false
      t.boolean :collab, default: false
      t.index :drawable_id, unique: true
      t.index %i[drawable_type drawable_id], name: 'index_gacha_on_drawable'
    end
    add_column :gacha_rateups, :gacha_id, :uuid
    add_index :gacha_rateups, :gacha_id
  end
end

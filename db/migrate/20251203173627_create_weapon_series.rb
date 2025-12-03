# frozen_string_literal: true

class CreateWeaponSeries < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_series, id: :uuid do |t|
      t.string :name_en, null: false
      t.string :name_jp, null: false
      t.string :slug, null: false
      t.integer :order, default: 0, null: false
      t.boolean :extra, default: false, null: false
      t.boolean :element_changeable, default: false, null: false
      t.boolean :has_weapon_keys, default: false, null: false
      t.boolean :has_awakening, default: false, null: false
      t.boolean :has_ax_skills, default: false, null: false
    end

    add_index :weapon_series, :slug, unique: true
    add_index :weapon_series, :order
  end
end

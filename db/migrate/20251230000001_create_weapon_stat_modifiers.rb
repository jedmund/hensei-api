# frozen_string_literal: true

class CreateWeaponStatModifiers < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_stat_modifiers do |t|
      t.string :slug, null: false
      t.string :name_en, null: false
      t.string :name_jp
      t.string :category, null: false
      t.string :stat
      t.integer :polarity, default: 1, null: false
      t.string :suffix
      t.float :base_min
      t.float :base_max
      t.integer :game_skill_id

      t.timestamps
    end

    add_index :weapon_stat_modifiers, :slug, unique: true
    add_index :weapon_stat_modifiers, :game_skill_id, unique: true
    add_index :weapon_stat_modifiers, :category
  end
end

# frozen_string_literal: true

class CreateWeaponSkillData < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_skill_data, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :modifier, null: false    # Template name: "Might", "Glory", "Enmity", etc.
      t.string :boost_type, null: false   # What it boosts: "atk", "ca_dmg", "ca_dmg_cap", "hp", etc.
      t.string :series, null: false       # "normal", "omega", "ex", "odious", "normal_omega"
      t.string :size, null: false         # "small", "medium", "big", "big_ii", "massive", "unworldly", "ancestral"
      t.string :formula_type, null: false, default: "flat" # "flat", "enmity", "stamina", "garrison"

      # Percentage values at key skill levels (nullable — formula-based entries may omit these)
      t.decimal :sl1,  precision: 10, scale: 4
      t.decimal :sl10, precision: 10, scale: 4
      t.decimal :sl15, precision: 10, scale: 4
      t.decimal :sl20, precision: 10, scale: 4
      t.decimal :sl25, precision: 10, scale: 4

      # Formula parameter for enmity/stamina/garrison curves
      t.decimal :coefficient, precision: 10, scale: 4

      t.boolean :aura_boostable, null: false, default: false

      t.timestamps
    end

    add_index :weapon_skill_data, [:modifier, :boost_type, :series, :size],
              unique: true, name: "index_weapon_skill_data_uniqueness"
    add_index :weapon_skill_data, :modifier
    add_index :weapon_skill_data, :series
  end
end

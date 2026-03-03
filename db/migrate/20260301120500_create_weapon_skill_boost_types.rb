# frozen_string_literal: true

class CreateWeaponSkillBoostTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_skill_boost_types, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string :key, null: false              # Snake_case key matching weapon_skill_data.boost_type: "atk", "ca_dmg_cap", etc.
      t.string :name_en, null: false           # Display name: "ATK", "C.A. DMG Cap"
      t.string :name_jp                        # Japanese display name (optional, for later)
      t.string :category, null: false          # Grouping: "offensive", "defensive", "multiattack", "cap", "supplemental", "utility"
      t.decimal :grid_cap, precision: 12, scale: 2 # Maximum total from all weapon skills (null if uncapped/unknown)
      t.boolean :cap_is_flat, null: false, default: false # true = flat value cap (e.g. 1,000,000), false = percentage
      t.string :stacking_rule, null: false, default: "additive" # "additive", "multiplicative_by_series", "highest_only"
      t.text :notes                            # Additional stacking/interaction notes

      t.timestamps
    end

    add_index :weapon_skill_boost_types, :key, unique: true
    add_index :weapon_skill_boost_types, :category
  end
end

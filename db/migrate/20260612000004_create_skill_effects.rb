# frozen_string_literal: true

class CreateSkillEffects < ActiveRecord::Migration[8.0]
  def up
    # Replaces a pre-existing, unused skill_effects table (old skill_id/effect_id
    # design) with the normalized character-skill effect rows. The old table had no
    # model or data, so dropping it is safe and not separately reversible.
    drop_table :skill_effects, if_exists: true

    create_table :skill_effects, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :character_skill_version, type: :uuid, null: false, foreign_key: true
      t.references :status, type: :uuid, null: true, foreign_key: true
      t.integer :ordinal, null: false
      t.string :effect_type, null: false
      t.string :target
      t.string :amount
      t.string :amount_max
      t.integer :duration_value
      t.string :duration_unit
      t.string :accuracy
      t.string :stacking_frame
      t.decimal :damage_pct, precision: 10, scale: 2
      t.integer :hit_count
      t.integer :damage_cap
      t.string :damage_element
      t.decimal :heal_pct, precision: 10, scale: 2
      t.integer :heal_cap
      t.text :raw
      t.timestamps
    end

    add_index :skill_effects, :effect_type
  end

  def down
    drop_table :skill_effects, if_exists: true
  end
end

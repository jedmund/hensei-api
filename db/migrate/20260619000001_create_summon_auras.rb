# frozen_string_literal: true

# Summon auras: a summon's passive aura(s), parsed from the wiki, per uncap/transcendence
# tier. Feeds the grid damage calculator (frame multipliers + Elemental boost).
#
# The table previously existed in schema.rb with no backing migration, no model, and no
# data/consumer. We replace it with a clean, calc-friendly schema.
class CreateSummonAuras < ActiveRecord::Migration[8.0]
  def up
    drop_table :summon_auras, if_exists: true

    create_table :summon_auras, id: :uuid do |t|
      t.string  :summon_granblue_id, null: false
      t.string  :slot, null: false, default: "main"          # main | sub
      t.string  :target, null: false                         # normal_frame|omega_frame|elemental_atk|normal_atk|omega_atk|multiattack|other
      t.string  :element                                     # fire|water|earth|wind|light|dark|all  (nil for frame auras — implied)
      t.decimal :value                                       # percent (nil when conditional/variable, e.g. Grand Order)
      t.integer :uncap_level, null: false, default: 0        # 0 (base, 0-2★) | 3 (MLB) | 4 (FLB) | 5 (ULB)
      t.integer :transcendence_stage, null: false, default: 0
      t.text    :condition                                   # main_summon | per_weapon_group | ...
      t.text    :description_en
      t.text    :description_jp

      t.timestamps
    end

    add_index :summon_auras, %i[summon_granblue_id slot uncap_level transcendence_stage],
              name: "index_summon_auras_on_summon_tier"
    add_index :summon_auras, :summon_granblue_id
  end

  def down
    drop_table :summon_auras, if_exists: true
  end
end

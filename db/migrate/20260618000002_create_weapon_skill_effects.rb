# frozen_string_literal: true

# Conditional / fixed-mechanic grid boosts (the "prose" weapon skills) that the
# SL-grid `weapon_skill_data` table can't represent: supplementals, per-grid-count
# boosts, threshold grants, ally/foe-HP-scaled effects, bonus damage, etc.
# See docs/damage/08-scaling-data-pipeline.md and 09-calculator-mvp.md.
class CreateWeaponSkillEffects < ActiveRecord::Migration[8.0]
  def change
    create_table :weapon_skill_effects, id: :uuid, default: -> { "gen_random_uuid()" } do |t|
      t.string  :modifier, null: false          # skill type name (join key), e.g. "Pact"
      t.string  :boost_type, null: false         # weapon_skill_boost_types key
      t.string  :series                          # ATK frame for atk effects: normal/omega/ex; null otherwise
      t.string  :scaling_kind, null: false       # foe_hp_supplemental|per_grid_count|conditional_flat|ally_hp_scaled|bonus_dmg|flat|static

      t.decimal :value, precision: 12, scale: 4         # per-unit/percent/factor
      t.string  :value_unit                             # percent|percent_foe_max_hp|percent_ally_max_hp|flat

      t.decimal :per_copy_cap, precision: 14, scale: 4  # cap per copy
      t.decimal :total_cap, precision: 14, scale: 4     # cap across copies/grid
      t.string  :shared_cap_group                       # e.g. "dmg_supp_shared", "voltage_wrath_grandepic"
      t.string  :cap_formula                            # HP-varying caps, e.g. "50000*((maxhp-curhp)/maxhp)+10000"

      t.string  :count_basis                            # weapon_type|weapon_group|epic|militis|same_id|omega_skill|skill_types
      t.integer :count_cap                              # max units counted (5, 10)

      t.jsonb   :condition, null: false, default: {}    # {type:"foe_debuff_count", gte:5} etc.
      t.string  :target_instance                        # all|normal_attack|charge_attack|skill|critical
      t.string  :depends_on, array: true, null: false, default: [] # state inputs: hp_percent, turn, foe_debuff_count, ally_buff_count, foe_count, grid_count, foe_max_hp, ally_max_hp, mc_crit_rate, foe_status

      t.boolean :aura_boostable, null: false, default: false
      t.boolean :seraphic_affected, null: false, default: false
      t.string  :stacking, null: false, default: "additive"      # additive|highest_only
      t.string  :applies_to, null: false, default: "element_allies" # element_allies|all_allies|mc_only
      t.boolean :battle_interaction, null: false, default: false # true = depends on enemy/ally buff state, excluded from core damage number
      t.text    :notes

      t.timestamps
    end

    add_index :weapon_skill_effects, :modifier
    add_index :weapon_skill_effects, [:modifier, :boost_type, :scaling_kind],
              unique: true, name: "index_weapon_skill_effects_uniqueness"
  end
end

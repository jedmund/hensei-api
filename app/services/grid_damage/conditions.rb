# frozen_string_literal: true

module GridDamage
  # Evaluates a weapon_skill_effect's structured condition (the jsonb `{type, gte|eq|is|
  # status}`) against the battle state, the grid composition, and the bearing weapon.
  # Used by GridDamage::Effects to decide whether a conditional effect applies.
  module Conditions
    module_function

    # condition:   parsed Hash (effect.condition); blank/{} ⇒ always true.
    # state:       BattleState-like Hash (debuff_count, mc_crit_rate, foe_element, …).
    # composition: GridComposition.for_party result.
    # weapon:      the Weapon bearing the effect (for skill/weapon level, same-id count).
    # grid_weapon: the GridWeapon copy (for per-copy state like transcendence).
    def met?(condition, state: {}, composition: {}, weapon: nil, grid_weapon: nil)
      return true if condition.blank?

      gte = condition["gte"]
      case condition["type"]
      when "weapon_group_count" then composition[:weapon_group_count].to_i >= gte
      when "same_id_count"      then composition.fetch(:id_counts, {}).fetch(weapon&.granblue_id, 0) >= gte
      when "skill_type_count"   then composition[:skill_type_count].to_i >= gte
      when "foe_debuff_count"   then state[:debuff_count].to_i >= gte
      when "mc_crit_rate"       then state[:mc_crit_rate].to_i >= gte
      when "skill_level"        then weapon&.max_skill_level.to_i >= gte
      when "weapon_level"       then weapon&.max_level.to_i >= gte
      # key-skill upgrades tied to the copy's transcendence (α Pendulum's lvl-240 DA/TA)
      when "transcendence_step" then grid_weapon && grid_weapon.transcendence_step.to_i >= gte
      # key-skill values that scale with the COPY's skill level (telumas: Inferno 25→30 at SL20)
      when "copy_skill_level"
        grid_weapon && weapon &&
          WeaponContributions.skill_level_for(weapon, grid_weapon) >= gte
      when "foe_element"        then state[:foe_element].to_s == condition["is"].to_s
      when "foe_status"         then Array(state[:foe_statuses]).include?(condition["status"])
      when "arcarum"            then !state[:arcarum].nil? && (!!state[:arcarum] == (condition["eq"] == true))
      when "boost_level"
        # self-referential: needs the per-frame enhancement totals, supplied by the
        # calculator's 2nd pass via state[:enhancements] (false in the 1st pass).
        enh = state[:enhancements] || {}
        [enh[:optimus], enh[:omega], enh[:taboo]].compact.map(&:to_f).max.to_f >= gte
      else false # unknown condition ⇒ conservatively not met
      end
    end
  end
end

# frozen_string_literal: true

module GridDamage
  # Evaluates a weapon_skill_effect's structured condition (the jsonb `{type, gte|eq|is|
  # status}`) against the battle state, the grid composition, and the bearing weapon.
  # Used by GridDamage::Effects to decide whether a conditional effect applies.
  module Conditions
    module_function

    # Condition kinds by what they read: the grid's composition, the bearing weapon or
    # its copy, or the battle state the panel is read at.
    COMPOSITION_TYPES = %w[count_basis_gte same_id_count skill_type_count weapon_specialty all_weapons_unique].freeze
    WEAPON_TYPES = %w[skill_level weapon_level transcendence_step copy_skill_level].freeze
    FOE_TYPES = %w[foe_debuff_count foe_element foe_status].freeze
    PANEL_TYPES = %w[mc_crit_rate turn_lte arcarum critical_capped boost_level].freeze

    # condition:   parsed Hash (effect.condition); blank/{} ⇒ always true.
    # state:       BattleState-like Hash (debuff_count, mc_crit_rate, foe_element, …).
    # composition: GridComposition.for_party result.
    # weapon:      the Weapon bearing the effect (for skill/weapon level, same-id count).
    # grid_weapon: the GridWeapon copy (for per-copy state like transcendence).
    # Whether the condition gates on Critical reaching its 100% cap: the Impulse family
    # applies on a critical hit and the panel lists it only at Critical 100% (czpldM and
    # SMBKDB show it there; mBaLHl at 50% and xblyJu at 96% don't).
    def crit_gated?(condition)
      condition.to_h['type'] == 'critical_capped'
    end

    def met?(condition, state: {}, composition: {}, weapon: nil, grid_weapon: nil)
      return true if condition.blank?

      type = condition['type']
      if COMPOSITION_TYPES.include?(type) then composition_met?(condition, composition: composition, weapon: weapon)
      elsif WEAPON_TYPES.include?(type) then weapon_met?(condition, weapon: weapon, grid_weapon: grid_weapon)
      elsif FOE_TYPES.include?(type) then foe_met?(condition, state: state)
      elsif PANEL_TYPES.include?(type) then panel_met?(condition, state: state)
      else false # unknown condition ⇒ conservatively not met
      end
    end

    # Conditions on what the grid holds.
    def composition_met?(condition, composition:, weapon:)
      gte = condition['gte']
      case condition['type']
      when 'count_basis_gte'
        return false unless GridComposition.valid_count_condition?(condition)

        GridComposition.count_for_basis(condition['basis'], weapon: weapon, composition: composition) >= gte
      when 'same_id_count'      then composition.fetch(:id_counts, {}).fetch(weapon&.granblue_id, 0) >= gte
      when 'skill_type_count'   then composition[:skill_type_count].to_i >= gte
      # Ultima base skills / gauph stat keys boost "<weapon>-specialty allies" — on the
      # panel (the MC's view) they show only when the MC's job wields this weapon's type
      # (K4UydX: Rising Force hides Baculum Rubell and Gauph Strength on an Ultima Staff).
      when 'weapon_specialty'
        specialty = GridComposition::PROFICIENCY_NAME[weapon&.proficiency]
        specialty.present? && Array(composition[:mc_specialties]).include?(specialty)
      # epic weapons' "when all equipped weapons are different" (Absolute Equality)
      when 'all_weapons_unique'
        counts = composition.fetch(:id_counts, {})
        counts.any? && counts.values.all? { |n| n <= 1 }
      end
    end

    # Conditions on the bearing weapon and its copy.
    def weapon_met?(condition, weapon:, grid_weapon:)
      gte = condition['gte']
      case condition['type']
      when 'skill_level'        then weapon&.max_skill_level.to_i >= gte
      when 'weapon_level'       then weapon&.max_level.to_i >= gte
      # key-skill upgrades tied to the copy's transcendence (α Pendulum's lvl-240 DA/TA)
      when 'transcendence_step' then grid_weapon && grid_weapon.transcendence_step.to_i >= gte
      # key-skill values that scale with the COPY's skill level (telumas: Inferno 25→30 at SL20)
      when 'copy_skill_level'
        grid_weapon && weapon &&
          WeaponContributions.skill_level_for(weapon, grid_weapon) >= gte
      end
    end

    # Conditions on the foe.
    def foe_met?(condition, state:)
      case condition['type']
      when 'foe_debuff_count' then state[:debuff_count].to_i >= condition['gte']
      when 'foe_element'      then state[:foe_element].to_s == condition['is'].to_s
      when 'foe_status'       then Array(state[:foe_statuses]).include?(condition['status'])
      end
    end

    # Conditions on the party's state when the panel is read.
    def panel_met?(condition, state:)
      case condition['type']
      when 'mc_crit_rate' then state[:mc_crit_rate].to_i >= condition['gte']
      # Preemptive/Betrayal-family skills apply through the end of the named turn.
      # Missing turn state means the calculator's default panel state: turn 1.
      when 'turn_lte' then state.fetch(:turn, 1).to_i <= condition['lte'].to_i
      when 'arcarum'  then !state[:arcarum].nil? && (!!state[:arcarum] == (condition['eq'] == true))
      # Met here; the panel gates it on the grid's Critical total, which only exists once
      # every contribution is aggregated (Calculator#drop_uncapped_crit_gated).
      when 'critical_capped' then true
      when 'boost_level'
        # self-referential: needs the per-frame enhancement totals, supplied by the
        # calculator's 2nd pass via state[:enhancements] (false in the 1st pass).
        enh = state[:enhancements] || {}
        [enh[:optimus], enh[:omega], enh[:taboo]].compact.map(&:to_f).max.to_f >= condition['gte']
      end
    end
  end
end

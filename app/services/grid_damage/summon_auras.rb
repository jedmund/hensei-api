# frozen_string_literal: true

module GridDamage
  # Resolves a party's SUMMON auras into per-frame totals for the grid element.
  # Aura sources: the main summon and the support/friend summon contribute their MAIN
  # aura; sub-aura summons (slots 4–5) contribute their SUB aura. Each summon's value is
  # picked transcendence-aware from summon_auras (e.g. a step-5 Varuna gives its 170%
  # transcended aura, not the 150% ULB value).
  module SummonAuras
    module_function

    # → { optimus:, omega:, taboo:, elemental: } percent totals.
    def for_party(party, element:)
      totals = { optimus: 0.0, omega: 0.0, taboo: 0.0, elemental: 0.0 }
      exo_fraction = odious_exorcism_fraction(party, element)
      party.summons.includes(:summon).each do |gs|
        slot = slot_for(gs)
        next unless slot && gs.summon

        gid = gs.summon.granblue_id
        u = gs.uncap_level.to_i
        t = gs.transcendence_step.to_i
        totals[:optimus]   += aura(gid, slot, "normal_frame", u, t)
        totals[:omega]     += aura(gid, slot, "omega_frame", u, t)
        totals[:taboo]     += taboo_aura(gid, slot, u, t, exo_fraction)
        totals[:elemental] += aura(gid, slot, "elemental_atk", u, t, element: element)
      end
      totals
    end

    # Odious summons scale with the equipped same-element Odious weapons' exorcision
    # levels, capped at 20 levels. Every Odious summon uses one per-level rate per uncap
    # tier (gbf.wiki/Belmervolk: 1/2/2.5/3.0% at 0/3/4/5★), from a base of 40 levels'
    # worth (40/80/100/120%) to 60 levels' worth at the cap (60/120/150/180%). The
    # stored rows say which summons are Odious; the rate table gives every tier, so a
    # summon's new 5★ needs no new row (0ZA6Ak: a 5★ Belmervolk at 180).
    ODIOUS_MAX_EXO_LEVELS = 20.0
    ODIOUS_RATE_BY_UNCAP = { 0 => 1.0, 3 => 2.0, 4 => 2.5, 5 => 3.0 }.freeze
    ODIOUS_BASE_LEVELS = 40.0

    def odious_exorcism_fraction(party, element)
      levels = party.weapons.filter_map do |gw|
        next unless gw.weapon&.weapon_series&.slug == "odious"
        next unless element.nil? || Calculator::ELEMENT_WORD[gw.weapon.element] == element

        [gw.exorcism_level.to_i, 1].max # weapons start at Exorcision Lvl 1
      end
      (levels.sum / ODIOUS_MAX_EXO_LEVELS).clamp(0.0, 1.0)
    end

    def taboo_aura(granblue_id, slot, uncap, _transcendence_step, exo_fraction)
      return 0.0 unless SummonAura.exists?(summon_granblue_id: granblue_id, slot: slot, target: "odious_frame")

      odious_aura(uncap, exo_fraction)
    end

    # Pure: an Odious summon's aura at an uncap level and exorcision fraction (0..1).
    def odious_aura(uncap, exo_fraction)
      rate = ODIOUS_RATE_BY_UNCAP.select { |tier, _| tier <= uncap }.max_by(&:first)&.last.to_f
      rate * (ODIOUS_BASE_LEVELS + (ODIOUS_MAX_EXO_LEVELS * exo_fraction))
    end

    # Main summon + support/friend supply their main aura; every other slot (the four
    # regular subs AND the two extra slots) supplies its sub aura — mcwZet: Lu Woh's 40%
    # Light-weapon-skill sub aura applies from a regular sub slot. Summons whose frame
    # boost is main-only (The Moon) simply have no sub-slot rows.
    def slot_for(grid_summon)
      grid_summon.main? || grid_summon.friend? ? "main" : "sub"
    end

    def aura(granblue_id, slot, target, uncap, transcendence_step, element: nil)
      rows = SummonAura.where(summon_granblue_id: granblue_id, slot: slot, target: target).to_a
      if element
        rows = rows.select { |r| r.element.nil? || r.element == "all" || r.element.to_s.include?(element.to_s) }
      end
      best_value(rows, uncap: uncap, transcendence_step: transcendence_step)
    end

    # Pure: the highest aura value among rows applicable at (uncap, transcendence_step).
    # A transcended summon (step > 0) may use the aurat tiers (stored at stage = aurat+1);
    # otherwise only the base tiers (stage 0) up to the uncap apply.
    def best_row(rows, uncap:, transcendence_step:)
      applicable = rows.select do |r|
        r.uncap_level.to_i <= uncap &&
          (r.transcendence_stage.to_i.zero? ||
           (transcendence_step.positive? && r.transcendence_stage.to_i <= transcendence_step + 1))
      end
      applicable.max_by { |r| [r.transcendence_stage.to_i, r.uncap_level.to_i, r.value.to_f] }
    end

    def best_value(rows, uncap:, transcendence_step:)
      best_row(rows, uncap: uncap, transcendence_step: transcendence_step)&.value.to_f
    end
  end
end

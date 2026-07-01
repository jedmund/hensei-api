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
      party.summons.includes(:summon).each do |gs|
        slot = slot_for(gs)
        next unless slot && gs.summon

        gid = gs.summon.granblue_id
        u = gs.uncap_level.to_i
        t = gs.transcendence_step.to_i
        totals[:optimus]   += aura(gid, slot, "normal_frame", u, t)
        totals[:omega]     += aura(gid, slot, "omega_frame", u, t)
        # Odious summons' base aura. Exorcism-level scaling (base → the aura's [Max]
        # via equipped Odious weapons' exorcism lvls) is undocumented on the wiki — the
        # per-level increment needs in-game ground truth before it can be modeled.
        totals[:taboo]     += aura(gid, slot, "odious_frame", u, t)
        totals[:elemental] += aura(gid, slot, "elemental_atk", u, t, element: element)
      end
      totals
    end

    # Main summon + support/friend supply their main aura; positions 4–5 their sub aura.
    def slot_for(grid_summon)
      return "main" if grid_summon.main? || grid_summon.friend?
      return "sub" if [4, 5].include?(grid_summon.position)

      nil
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
    def best_value(rows, uncap:, transcendence_step:)
      applicable = rows.select do |r|
        r.uncap_level.to_i <= uncap &&
          (r.transcendence_stage.to_i.zero? ||
           (transcendence_step.positive? && r.transcendence_stage.to_i <= transcendence_step + 1))
      end
      applicable.max_by { |r| [r.transcendence_stage.to_i, r.uncap_level.to_i, r.value.to_f] }&.value.to_f || 0.0
    end
  end
end

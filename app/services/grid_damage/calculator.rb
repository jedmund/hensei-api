# frozen_string_literal: true

module GridDamage
  # Orchestrator: merges weapon-skill DATA (Phase 1/2), conditional EFFECTS (Phase 5), and
  # KEY-granted skills (Phase 6) into the in-game "Weapon Skill Boosts" list. Runs a second
  # pass when any frame enhancement reaches ≥280%, so self-referential `boost_level`
  # effects (Opus pendulums, Destroyer anklets) can activate.
  module Calculator
    module_function

    ELEMENT_WORD = { 1 => "wind", 2 => "fire", 3 => "water", 4 => "earth", 5 => "dark", 6 => "light" }.freeze
    BOOST_LEVEL_THRESHOLD = 280.0

    # → { boost_type => Aggregator::Result } for the party at the given battle state.
    def boost_list(party, state: {})
      composition = GridComposition.for_party(party)
      agg = aggregate_pass(party, state, composition)

      enh = enhancements(party, agg)
      return agg if enh.values.max.to_f < BOOST_LEVEL_THRESHOLD # no ≥280 effects can fire

      aggregate_pass(party, state.merge(enhancements: enh), composition)
    end

    # Per-frame enhancement totals (summon + character auras + Exalto) — what `boost_level`
    # conditions compare against.
    def enhancements(party, agg)
      element = grid_element(party)
      auras = Auras.for_party(party, element: element)
      {
        optimus: auras[:optimus] + [agg["optimus_exalto"]&.total.to_f || 0.0, 90].min,
        omega: auras[:omega] + [agg["omega_exalto"]&.total.to_f || 0.0, 100].min,
        taboo: 0.0 # Odious/Taboo enhancement — wired when the odious frame is modeled
      }
    end

    def aggregate_pass(party, state, composition)
      contributions = WeaponContributions.for_party(party, state: state) +
                      Effects.contributions(party, state: state, composition: composition) +
                      KeySkills.contributions(party, state: state, composition: composition)
      Aggregator.aggregate(contributions)
    end

    def grid_element(party)
      id = party.weapons.filter_map { |gw| gw.element || gw.weapon&.element }
                .group_by(&:itself).max_by { |_, v| v.size }&.first
      ELEMENT_WORD[id]
    end

    private_class_method :enhancements, :aggregate_pass, :grid_element
  end
end

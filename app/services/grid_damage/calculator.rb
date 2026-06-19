# frozen_string_literal: true

module GridDamage
  # Thin orchestrator: merges the weapon-skill DATA contributions (Phase 1/2) and the
  # conditional-EFFECTS contributions (Phase 5), then aggregates them into the in-game
  # "Weapon Skill Boosts" list. Frame math / Estimated DMG build on this (Phase 6).
  module Calculator
    module_function

    # → { boost_type => Aggregator::Result } for the party at the given battle state.
    def boost_list(party, state: {})
      composition = GridComposition.for_party(party)
      contributions = WeaponContributions.for_party(party, state: state) +
                      Effects.contributions(party, state: state, composition: composition)
      Aggregator.aggregate(contributions)
    end
  end
end

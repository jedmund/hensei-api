# frozen_string_literal: true

module GridDamage
  # The grid's total aura (what the in-game panel calls "Weapon Skill Enhancements",
  # minus Exalto): summon auras + character support-skill auras, per frame, for the grid
  # element. Exalto comes from the weapon aggregation and is added in the frame math.
  module Auras
    module_function

    # → { optimus:, omega:, elemental: } percent totals.
    def for_party(party, element:)
      summon = SummonAuras.for_party(party, element: element)
      character = CharacterAuras.for_party(party, element: element)
      {
        optimus: summon[:optimus] + character[:optimus],
        omega: summon[:omega] + character[:omega],
        elemental: summon[:elemental]
      }
    end
  end
end

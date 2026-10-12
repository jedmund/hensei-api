# frozen_string_literal: true

# Loads a party with everything the PartyBlueprint :full view touches, so a
# full-view response renders without N+1 queries over the grid items.
# Requires SubstituteGridPreloading.
module PartyFullLoading
  extend ActiveSupport::Concern

  private

  # Associations the PartyBlueprint :full view touches. Eager-loaded by every
  # action that serializes a full party.
  def full_party_preloads
    [
      :user, :job, { raid: :group },
      { characters: GridCharacter::NESTED_BLUEPRINT_PRELOADS + [{ substitutions: :substitute_grid }] },
      { weapons: GridWeapon::NESTED_BLUEPRINT_PRELOADS + [{ substitutions: :substitute_grid }] },
      { summons: GridSummon::NESTED_BLUEPRINT_PRELOADS + [{ substitutions: :substitute_grid }] },
      :guidebook1, :guidebook2, :guidebook3,
      { source_party: [{ characters: :character }, { weapons: :weapon }, { summons: :summon }] },
      { remixes: [{ characters: :character }, { weapons: :weapon }, { summons: :summon }] },
      :skill0, :skill1, :skill2, :skill3, :accessory,
      { party_shares: :shareable },
      { solomonis_expedition: %i[route_evoker build_party] },
      { party_blessings: %i[arcarum_blessing arcarum_blessing_level] },
      { expedition_guide_effects: :solomonis_guide_effect }
    ]
  end

  # Re-fetches a party by id with all blueprint associations (and substitute
  # collection data) preloaded. Mutating actions hold a non-eager-loaded
  # party, so they round-trip through this before serializing.
  def load_full_party(id)
    party = Party.includes(full_party_preloads).find_by(id: id)
    return party unless party&.has_substitutions?

    preload_substitute_grids!(party.characters + party.weapons + party.summons)
    party
  end
end

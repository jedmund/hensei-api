# frozen_string_literal: true

module Granblue
  # Conversions between the game's own numbering and Hensei's.
  module GameIds
    # The game's weapon kind (artifact `kind`, Solomonis guide effect
    # `target_param` for weapon specialties) to Hensei's proficiency.
    # Game:   1 Sabre, 2 Dagger, 3 Spear, 4 Axe, 5 Staff, 6 Gun, 7 Melee, 8 Bow, 9 Harp, 10 Katana
    # Hensei: 1 Sabre, 2 Dagger, 3 Axe, 4 Spear, 5 Bow, 6 Staff, 7 Melee, 8 Harp, 9 Gun, 10 Katana
    WEAPON_KIND_TO_PROFICIENCY = {
      1 => 1,   # Sabre
      2 => 2,   # Dagger
      3 => 4,   # Spear
      4 => 3,   # Axe
      5 => 6,   # Staff
      6 => 9,   # Gun
      7 => 7,   # Melee
      8 => 5,   # Bow
      9 => 8,   # Harp
      10 => 10  # Katana
    }.freeze

    PROFICIENCY_TO_WEAPON_KIND = WEAPON_KIND_TO_PROFICIENCY.invert.freeze

    module_function

    # @param kind [Integer, String] the game's weapon kind
    # @return [Integer, nil] Hensei's proficiency, or nil when the kind is unknown
    def proficiency_for_weapon_kind(kind)
      return nil unless kind.to_s.match?(/\A\d+\z/)

      WEAPON_KIND_TO_PROFICIENCY[kind.to_i]
    end

    # @param proficiency [Integer, String] Hensei's proficiency
    # @return [Integer, nil] the game's weapon kind
    def weapon_kind_for_proficiency(proficiency)
      return nil unless proficiency.to_s.match?(/\A\d+\z/)

      PROFICIENCY_TO_WEAPON_KIND[proficiency.to_i]
    end
  end
end

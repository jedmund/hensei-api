# frozen_string_literal: true

module Api
  module V1
    class SubstitutionBlueprint < ApiBlueprint
      field :position

      # Keeps the wire shape stable (three discriminated keys) — clients pick
      # the right one by checking which is present.
      {
        'GridCharacter' => [:grid_character, GridCharacterBlueprint],
        'GridWeapon'    => [:grid_weapon,    GridWeaponBlueprint],
        'GridSummon'    => [:grid_summon,    GridSummonBlueprint]
      }.each do |type, (name, blueprint)|
        association :substitute_grid, name: name, blueprint: blueprint, view: :nested,
                    if: ->(_field_name, sub, _options) { sub.substitute_grid_type == type }
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class SubstitutionBlueprint < ApiBlueprint
      field :position

      association :substitute_grid, blueprint: GridCharacterBlueprint, view: :nested,
                  if: ->(_field_name, sub, _options) { sub.substitute_grid_type == 'GridCharacter' }

      association :substitute_grid, name: :grid_weapon, blueprint: GridWeaponBlueprint, view: :nested,
                  if: ->(_field_name, sub, _options) { sub.substitute_grid_type == 'GridWeapon' }

      association :substitute_grid, name: :grid_summon, blueprint: GridSummonBlueprint, view: :nested,
                  if: ->(_field_name, sub, _options) { sub.substitute_grid_type == 'GridSummon' }
    end
  end
end

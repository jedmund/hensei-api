# frozen_string_literal: true

module Api
  module V1
    class SubstitutionBlueprint < ApiBlueprint
      field :position

      field :grid_character, if: ->(_fn, sub, _opt) { sub.grid_type == 'GridCharacter' } do |sub|
        GridCharacterBlueprint.render_as_hash(sub.substitute_grid, view: :nested)
      end

      field :grid_weapon, if: ->(_fn, sub, _opt) { sub.grid_type == 'GridWeapon' } do |sub|
        GridWeaponBlueprint.render_as_hash(sub.substitute_grid, view: :nested)
      end

      field :grid_summon, if: ->(_fn, sub, _opt) { sub.grid_type == 'GridSummon' } do |sub|
        GridSummonBlueprint.render_as_hash(sub.substitute_grid, view: :nested)
      end
    end
  end
end

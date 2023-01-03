# frozen_string_literal: true

module Api
  module V1
    class GridWeaponBlueprint < ApiBlueprint
      view :uncap do
        association :party, blueprint: PartyBlueprint, view: :minimal
        fields :position, :uncap_level
      end

      view :nested do
        fields :mainhand, :position, :uncap_level, :element
        association :weapon, name: :object, blueprint: WeaponBlueprint

        association :weapon_keys,
                    blueprint: WeaponKeyBlueprint,
                    if: lambda { |_field_name, w, _options|
                      [2, 3, 17, 24].include?(w.weapon.series)
                    }

        field :ax, if: ->(_field_name, w, _options) { w.weapon.ax } do |w|
          [
            {
              modifier: w.ax_modifier1,
              strength: w.ax_strength1
            },
            {
              modifier: w.ax_modifier2,
              strength: w.ax_strength2
            }
          ]
        end
      end

      field :awakening, if: ->(_field_name, w, _options) { w.weapon.awakening } do |w|
        {
          type: w.awakening_type,
          level: w.awakening_level
        }
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :minimal
      end
    end
  end
end

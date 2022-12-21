# frozen_string_literal: true

module Api
  module V1
    class GridWeaponBlueprint < ApiBlueprint
      view :nested do
        fields :id, :mainhand, :position, :uncap_level, :element
        association :weapon, name: :object, blueprint: WeaponBlueprint

        association :weapon_keys,
                    blueprint: WeaponKeyBlueprint,
                    if: lambda { |_field_name, w, _options|
                      [2, 3, 17, 22].include?(w.weapon.series)
                    }

        field :ax, if: ->(_field_name, w, _options) { w.weapon.ax.positive? } do |w|
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

      view :full do
        fields :party_id
      end
    end
  end
end

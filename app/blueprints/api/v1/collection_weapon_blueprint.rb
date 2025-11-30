module Api
  module V1
    class CollectionWeaponBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :element,
             :created_at, :updated_at

      field :ax, if: ->(_, obj, _) { obj.ax_modifier1.present? } do |obj|
        [
          { modifier: obj.ax_modifier1, strength: obj.ax_strength1 },
          { modifier: obj.ax_modifier2, strength: obj.ax_strength2 }
        ].compact_blank
      end

      field :awakening, if: ->(_, obj, _) { obj.awakening.present? } do |obj|
        {
          type: AwakeningBlueprint.render_as_hash(obj.awakening),
          level: obj.awakening_level
        }
      end

      association :weapon, blueprint: WeaponBlueprint
      association :weapon_keys, blueprint: WeaponKeyBlueprint,
                  if: ->(_, obj, _) { obj.weapon_keys.any? }

      view :full do
        association :weapon, blueprint: WeaponBlueprint, view: :full
      end
    end
  end
end
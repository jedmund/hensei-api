module Api
  module V1
    class CollectionWeaponBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :element, :exorcism_level,
             :created_at, :updated_at

      field :ax, if: ->(_, obj, _) { obj.ax_modifier1.present? } do |obj|
        skills = []
        if obj.ax_modifier1.present?
          skills << {
            modifier: WeaponStatModifierBlueprint.render_as_hash(obj.ax_modifier1),
            strength: obj.ax_strength1
          }
        end
        if obj.ax_modifier2.present?
          skills << {
            modifier: WeaponStatModifierBlueprint.render_as_hash(obj.ax_modifier2),
            strength: obj.ax_strength2
          }
        end
        skills
      end

      field :befoulment, if: ->(_, obj, _) { obj.befoulment_modifier.present? } do |obj|
        {
          modifier: WeaponStatModifierBlueprint.render_as_hash(obj.befoulment_modifier),
          strength: obj.befoulment_strength,
          exorcism_level: obj.exorcism_level
        }
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
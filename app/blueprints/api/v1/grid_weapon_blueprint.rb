# frozen_string_literal: true

module Api
  module V1
    class GridWeaponBlueprint < ApiBlueprint
      fields :mainhand, :position, :uncap_level, :transcendence_step, :element, :exorcism_level, :orphaned

      field :collection_weapon_id
      field :out_of_sync, if: ->(_field, gw, _options) { gw.collection_weapon_id.present? } do |gw|
        gw.out_of_sync?
      end

      view :preview do
        association :weapon, blueprint: WeaponBlueprint, view: :preview
      end

      view :nested do
        field :ax, if: ->(_field_name, w, _options) { w.ax_modifier1.present? } do |w|
          skills = []
          if w.ax_modifier1.present?
            skills << {
              modifier: WeaponStatModifierBlueprint.render_as_hash(w.ax_modifier1),
              strength: w.ax_strength1
            }
          end
          if w.ax_modifier2.present?
            skills << {
              modifier: WeaponStatModifierBlueprint.render_as_hash(w.ax_modifier2),
              strength: w.ax_strength2
            }
          end
          skills
        end

        field :befoulment, if: ->(_field_name, w, _options) { w.befoulment_modifier.present? } do |w|
          {
            modifier: WeaponStatModifierBlueprint.render_as_hash(w.befoulment_modifier),
            strength: w.befoulment_strength,
            exorcism_level: w.exorcism_level
          }
        end

        field :awakening, if: ->(_field_name, w, _options) { w.awakening.present? } do |w|
          {
            type: AwakeningBlueprint.render_as_hash(w.awakening),
            level: w.awakening_level
          }
        end

        association :weapon, blueprint: WeaponBlueprint, view: :full,
                    if: ->(_field_name, w, _options) { w.weapon.present? }

        association :weapon_keys,
                    blueprint: WeaponKeyBlueprint,
                    if: ->(_field_name, w, _options) {
                      w.weapon.present? &&
                        w.weapon.weapon_series.present? &&
                        w.weapon.weapon_series.has_weapon_keys
                    }
        association :role, blueprint: RoleBlueprint,
                    if: ->(_fn, gw, _opt) { gw.role.present? }
        field :substitution_note, if: ->(_fn, gw, _opt) { gw.substitution_note.present? }
        association :substitutions, blueprint: SubstitutionBlueprint,
                    if: ->(_fn, gw, _opt) { !gw.is_substitute? && gw.substitutions.any? }
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :collection_source
      end

      view :uncap do
        association :party, blueprint: PartyBlueprint
        fields :position, :uncap_level, :transcendence_step
      end

      view :destroyed do
        fields :mainhand, :position, :created_at, :updated_at
      end
    end
  end
end

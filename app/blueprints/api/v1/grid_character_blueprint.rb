# frozen_string_literal: true

module Api
  module V1
    class GridCharacterBlueprint < ApiBlueprint
      fields :position, :uncap_level, :perpetuity

      field :transcendence_step, if: ->(_field, gc, _options) { gc.character&.ulb } do |gc|
        gc.transcendence_step
      end

      view :preview do
        association :character, blueprint: CharacterBlueprint
      end

      view :nested do
        include_view :mastery_bonuses
        association :character, blueprint: CharacterBlueprint, view: :full
      end

      view :uncap do
        association :party, blueprint: PartyBlueprint, view: :minimal
        fields :position, :uncap_level
      end

      view :destroyed do
        fields :position, :created_at, :updated_at
      end

      view :mastery_bonuses do
        field :awakening, if: ->(_field_name, gc, _options) { gc.association(:awakening).loaded? } do |gc|
          {
            type: AwakeningBlueprint.render_as_hash(gc.awakening),
            level: gc.awakening_level
          }
        end

        field :over_mastery, if: lambda { |_fn, obj, _opt|
          !obj.ring1['modifier'].nil? && !obj.ring2['modifier'].nil?
        } do |c|
          [c.ring1, c.ring2, c.ring3, c.ring4].reject { |ring| ring['modifier'].nil? }
        end

        field :aetherial_mastery, if: lambda { |_fn, obj, _opt|
          !obj.earring['modifier'].nil?
        }, &:earring
      end
    end
  end
end

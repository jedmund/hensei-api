# frozen_string_literal: true

module Api
  module V1
    class GridCharacterBlueprint < ApiBlueprint
      view :uncap do
        association :party, blueprint: PartyBlueprint, view: :minimal
        fields :position, :uncap_level
      end

      view :nested do
        fields :position, :uncap_level, :perpetuity

        field :transcendence_step, if: lambda { |_fn, obj, _opt|
          obj.character.ulb
        } do |c|
          c.transcendence_step
        end

        field :awakening do |c|
<<<<<<< HEAD
          c.awakening
        end

        field :over_mastery, if: lambda { |_fn, obj, _opt|
          !obj.ring1['modifier'].nil? && !obj.ring2['modifier'].nil?
        } do |c|
          rings = []

          rings.push(c.ring1) unless c.ring1['modifier'].nil?
          rings.push(c.ring2) unless c.ring2['modifier'].nil?
          rings.push(c.ring3) unless c.ring3['modifier'].nil?
          rings.push(c.ring4) unless c.ring4['modifier'].nil?

          rings
        end

        field :aetherial_mastery, if: lambda { |_fn, obj, _opt|
          !obj.earring['modifier'].nil?
        } do |c|
          c.earring
=======
          {
            type: AwakeningBlueprint.render_as_hash(c.awakening),
            level: c.awakening_level
          }
>>>>>>> main
        end

        field :over_mastery, if: lambda { |_fn, obj, _opt|
          !obj.ring1['modifier'].nil? && !obj.ring2['modifier'].nil?
        } do |c|
          rings = []

          rings.push(c.ring1) unless c.ring1['modifier'].nil?
          rings.push(c.ring2) unless c.ring2['modifier'].nil?
          rings.push(c.ring3) unless c.ring3['modifier'].nil?
          rings.push(c.ring4) unless c.ring4['modifier'].nil?

          rings
        end

        field :aetherial_mastery, if: lambda { |_fn, obj, _opt|
          !obj.earring['modifier'].nil?
        } do |c|
          c.earring
        end

        association :character, name: :object, blueprint: CharacterBlueprint
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :minimal
      end

      view :destroyed do
        fields :position, :created_at, :updated_at
      end
    end
  end
end

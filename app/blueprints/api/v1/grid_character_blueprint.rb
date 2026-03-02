# frozen_string_literal: true

module Api
  module V1
    class GridCharacterBlueprint < ApiBlueprint
      fields :position, :uncap_level, :perpetuity

      field :transcendence_step, if: ->(_field, gc, _options) { gc.character&.ulb } do |gc|
        gc.transcendence_step
      end

      field :collection_character_id
      field :out_of_sync, if: ->(_field, gc, _options) { gc.collection_character_id.present? } do |gc|
        gc.out_of_sync?
      end

      view :preview do
        association :character, blueprint: CharacterBlueprint
      end

      view :nested do
        include_view :mastery_bonuses
        association :character, blueprint: CharacterBlueprint, view: :full
        association :grid_artifact, blueprint: GridArtifactBlueprint, view: :nested,
                    if: ->(_field_name, gc, _options) { gc.grid_artifact.present? }
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
        fields :position, :created_at, :updated_at
      end

      view :mastery_bonuses do
        field :awakening, if: ->(_field_name, gc, _options) { gc.association(:awakening).loaded? } do |gc|
          {
            type: AwakeningBlueprint.render_as_hash(gc.awakening),
            level: gc.awakening_level.to_i
          }
        end

        field :over_mastery, if: lambda { |_fn, obj, _opt|
          obj.ring1.present? && obj.ring2.present? && !obj.ring1['modifier'].nil? && !obj.ring2['modifier'].nil?
        } do |c|
          mapped_rings = [c.ring1, c.ring2, c.ring3, c.ring4].each_with_object([]) do |ring, arr|
            # Skip if the ring is nil or its modifier is blank.
            next if ring.blank? || ring['modifier'].blank?

            # Convert the string values to numbers.
            mod = ring['modifier'].to_i

            # Only include if modifier is non-zero.
            next if mod.zero?

            arr << { modifier: mod, strength: ring['strength'].to_i }
          end

          mapped_rings
        end

        field :aetherial_mastery, if: ->(_fn, obj, _opt) { obj.earring.present? && !obj.earring['modifier'].nil? } do |gc, _options|
          {
            modifier: gc.earring['modifier'].to_i,
            strength: gc.earring['strength'].to_i
          }
        end
      end
    end
  end
end

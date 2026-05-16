# frozen_string_literal: true

module Api
  module V1
    class GridCharacterBlueprint < ApiBlueprint
      fields :position, :uncap_level, :perpetuity

      field :transcendence_step, if: ->(_field, gc, _options) { gc.character&.transcendence } do |gc|
        gc.transcendence_step
      end

      field :collection_character_id
      field :out_of_sync, if: ->(_field, gc, _options) { gc.collection_character_id.present? } do |gc|
        gc.out_of_sync?
      end
      field :out_of_sync_fields, if: ->(_field, gc, _options) { gc.collection_character_id.present? } do |gc|
        gc.out_of_sync_fields
      end
      # Stamped by SubstituteGridPreloading when this is rendered as a
      # substitute. Indicates whether current_user owns the underlying
      # character in their collection.
      field :owned, if: ->(_field, gc, _options) { !gc.owned.nil? }

      view :preview do
        association :character, blueprint: CharacterBlueprint, view: :preview
      end

      # Minimal view for party list cards
      view :list do
        excludes :perpetuity, :collection_character_id, :out_of_sync, :out_of_sync_fields
        association :character, blueprint: CharacterBlueprint, view: :list
      end

      view :nested do
        include_view :mastery_bonuses
        association :character, blueprint: CharacterBlueprint, view: :full
        association :grid_artifact, blueprint: GridArtifactBlueprint, view: :nested,
                    if: ->(_field_name, gc, _options) { gc.grid_artifact.present? }

        field :roles, if: ->(_field_name, gc, _options) { gc.grid_character_roles.any? } do |gc|
          GridCharacterRoleBlueprint.render_as_hash(gc.grid_character_roles.sort_by(&:sort_order))
        end
        field :description, if: ->(_field_name, gc, _options) { gc.description.present? }
        association :substitutions, blueprint: SubstitutionBlueprint,
                    if: ->(_field_name, gc, _options) { !gc.is_substitute? && gc.substitutions.any? }
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
        # `.loaded?` is true even when the association resolved to nil, so it
        # can't gate a render that calls `.id` on the value. Check presence.
        field :awakening, if: ->(_field_name, gc, _options) { gc.awakening.present? } do |gc|
          {
            type: AwakeningBlueprint.render_as_hash(gc.awakening),
            level: gc.awakening_level.to_i
          }
        end

        # Positional ring loadout shared with CollectionCharacterBlueprint —
        # always emitted as a length-4 array. Empty slots are null so frontend
        # readers can rely on positional access (overMastery[0] is ATK,
        # overMastery[1] is HP, etc.).
        field :over_mastery do |c|
          [c.ring1, c.ring2, c.ring3, c.ring4].map do |ring|
            CollectionCharacterBlueprint.serialize_ring(ring)
          end
        end

        # Single earring slot or null. Same shape as CollectionCharacter.
        field :aetherial_mastery do |gc, _options|
          CollectionCharacterBlueprint.serialize_ring(gc.earring)
        end
      end
    end
  end
end

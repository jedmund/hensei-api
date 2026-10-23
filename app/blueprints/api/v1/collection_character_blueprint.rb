module Api
  module V1
    class CollectionCharacterBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :perpetuity,
             :created_at, :updated_at

      # Positional ring loadout. Always emitted as a length-4 array so callers
      # can index into a fixed slot (ring1 = ATK, ring2 = HP, ring3/4 = optional
      # secondary/tertiary). Empty slots are null.
      field :over_mastery do |obj|
        [obj.ring1, obj.ring2, obj.ring3, obj.ring4].map do |ring|
          serialize_ring(ring)
        end
      end

      # Single earring slot or null when unset. Renamed from `earring` to
      # `aetherial_mastery` so it matches the GridCharacter shape — both
      # sides now read the same key.
      field :aetherial_mastery do |obj|
        serialize_ring(obj.earring)
      end

      field :awakening do |obj|
        if obj.awakening.present?
          {
            type: AwakeningBlueprint.render_as_hash(obj.awakening),
            level: obj.awakening_level
          }
        end
      end

      association :character, blueprint: CharacterBlueprint

      view :full do
        association :character, blueprint: CharacterBlueprint, view: :full
      end

      # Coerces a ring/earring JSONB hash into the canonical { modifier, strength }
      # shape, or nil for any "empty" representation (null, missing keys, zeros).
      def self.serialize_ring(ring)
        return nil if ring.blank?

        modifier = ring['modifier']
        strength = ring['strength']
        return nil if modifier.nil? || modifier.to_i.zero?
        return nil if strength.nil? || strength.to_i.zero?

        { modifier: modifier.to_i, strength: strength.to_i }
      end
    end
  end
end

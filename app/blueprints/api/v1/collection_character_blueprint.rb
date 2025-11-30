module Api
  module V1
    class CollectionCharacterBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :perpetuity,
             :ring1, :ring2, :ring3, :ring4, :earring,
             :created_at, :updated_at

      field :awakening, if: ->(_, obj, _) { obj.awakening.present? } do |obj|
        {
          type: AwakeningBlueprint.render_as_hash(obj.awakening),
          level: obj.awakening_level
        }
      end

      association :character, blueprint: CharacterBlueprint

      view :full do
        association :character, blueprint: CharacterBlueprint, view: :full
      end
    end
  end
end
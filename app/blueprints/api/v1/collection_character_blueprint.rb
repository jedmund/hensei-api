module Api
  module V1
    class CollectionCharacterBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step, :perpetuity,
             :ring1, :ring2, :ring3, :ring4, :earring,
             :created_at, :updated_at

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
    end
  end
end
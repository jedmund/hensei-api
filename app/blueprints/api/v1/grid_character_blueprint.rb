# frozen_string_literal: true

module Api
  module V1
    class GridCharacterBlueprint < ApiBlueprint
      view :nested do
        fields :id, :position, :uncap_level, :perpetuity
        association :character, name: :object, blueprint: CharacterBlueprint
      end

      view :full do
        fields :party_id
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class GridCharacterBlueprint < ApiBlueprint
      identifier :id

      view :uncap do
        association :party, blueprint: PartyBlueprint
        fields :position, :uncap_level
      end

      view :nested do
        fields :position, :uncap_level, :perpetuity
        association :character, name: :object, blueprint: CharacterBlueprint
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :preview
      end
    end
  end
end

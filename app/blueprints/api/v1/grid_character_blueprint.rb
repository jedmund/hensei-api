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
        association :character, name: :object, blueprint: CharacterBlueprint
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :minimal
      end
    end
  end
end

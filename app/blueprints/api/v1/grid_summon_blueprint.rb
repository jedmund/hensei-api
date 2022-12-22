# frozen_string_literal: true

module Api
  module V1
    class GridSummonBlueprint < ApiBlueprint
      identifier :id

      view :uncap do
        association :party, blueprint: PartyBlueprint
        fields :position, :uncap_level
      end

      view :nested do
        fields :main, :friend, :position, :uncap_level
        association :summon, name: :object, blueprint: SummonBlueprint
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint
      end
    end
  end
end

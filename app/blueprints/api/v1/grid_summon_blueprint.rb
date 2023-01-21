# frozen_string_literal: true

module Api
  module V1
    class GridSummonBlueprint < ApiBlueprint
      view :uncap do
        association :party, blueprint: PartyBlueprint, view: :minimal
        fields :position, :uncap_level
      end

      view :nested do
        fields :main, :friend, :position, :uncap_level
        association :summon, name: :object, blueprint: SummonBlueprint
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :minimal
      end

      view :destroyed do
        fields :main, :friend, :position, :created_at, :updated_at
      end
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class GridSummonBlueprint < ApiBlueprint
      view :nested do
        fields :id, :main, :friend, :position, :uncap_level
        association :summon, name: :object, blueprint: SummonBlueprint
      end

      view :full do
        fields :party_id
      end
    end
  end
end

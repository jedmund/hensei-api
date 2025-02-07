# frozen_string_literal: true

module Api
  module V1
    class GridSummonBlueprint < ApiBlueprint
      fields :main, :friend, :position, :quick_summon, :uncap_level, :transcendence_step

      view :preview do
        association :summon, name: :object, blueprint: SummonBlueprint
      end

      view :nested do
        association :summon, name: :object, blueprint: SummonBlueprint, view: :full
      end

      view :full do
        include_view :nested
        association :party, blueprint: PartyBlueprint, view: :minimal
      end

      view :uncap do
        association :party, blueprint: PartyBlueprint, view: :minimal
        fields :position, :uncap_level, :transcendence_step
      end

      view :destroyed do
        fields :main, :friend, :position, :created_at, :updated_at
      end
    end
  end
end

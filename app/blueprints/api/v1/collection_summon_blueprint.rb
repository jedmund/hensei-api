module Api
  module V1
    class CollectionSummonBlueprint < ApiBlueprint
      identifier :id

      fields :uncap_level, :transcendence_step,
             :created_at, :updated_at

      association :summon, blueprint: SummonBlueprint

      view :full do
        association :summon, blueprint: SummonBlueprint, view: :full
      end
    end
  end
end
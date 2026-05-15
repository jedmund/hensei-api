module Api
  module V1
    class SupportSummonBlueprint < ApiBlueprint
      identifier :id

      fields :section, :position, :created_at, :updated_at

      association :collection_summon, blueprint: CollectionSummonBlueprint

      view :full do
        association :collection_summon, blueprint: CollectionSummonBlueprint, view: :full
      end
    end
  end
end

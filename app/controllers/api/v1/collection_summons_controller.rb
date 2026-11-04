# frozen_string_literal: true

module Api
  module V1
    # Summons in a user's collection. A user can own several copies of a summon.
    class CollectionSummonsController < CollectionItemsController
      include Concerns::CollectionInventorySync

      collection_item :summon,
                      catalog: Summon,
                      blueprint: Api::V1::CollectionSummonBlueprint,
                      catalog_blueprint: SummonBlueprint,
                      catalog_view: :dates,
                      import_service: SummonImportService,
                      permitted: %i[summon_id uncap_level transcendence_step],
                      owned_includes: { summon: :summon_series },
                      unowned_includes: :summon_series,
                      owned_filters: {
                        summon_id: CollectionItemQuery::Filter.exact(:by_summon),
                        support_eligible: CollectionItemQuery::Filter.flag(:support_eligible)
                      },
                      unowned_filters: {
                        series: :summon_series_id,
                        support_eligible: CollectionItemQuery::Filter.flag(:support_eligible)
                      }

      private

      # Game data can carry a Forged Arcarum id that maps to another summon.
      def resolve_granblue_id(granblue_id)
        SummonIdMapping.resolve(granblue_id)
      end
    end
  end
end

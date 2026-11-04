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
                      unowned_includes: :summon_series

      private

      def filter_owned_by_type(scope)
        scope = scope.by_summon(params[:summon_id]) if params[:summon_id]
        scope = scope.support_eligible if support_eligible_only?
        scope
      end

      def filter_unowned_by_type(scope)
        scope = scope.where(summon_series_id: array_param(:series)) if params[:series]
        scope = scope.where(support_eligible: true) if support_eligible_only?
        scope
      end

      def support_eligible_only?
        ActiveModel::Type::Boolean.new.cast(params[:support_eligible])
      end

      # Game data can carry a Forged Arcarum id that maps to another summon.
      def resolve_granblue_id(granblue_id)
        SummonIdMapping.resolve(granblue_id)
      end
    end
  end
end

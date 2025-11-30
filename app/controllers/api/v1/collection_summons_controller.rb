module Api
  module V1
    class CollectionSummonsController < ApiController
      before_action :restrict_access
      before_action :set_collection_summon, only: %i[show update destroy]

      def index
        @collection_summons = current_user.collection_summons
                                          .includes(:summon)

        @collection_summons = @collection_summons.by_summon(params[:summon_id]) if params[:summon_id]
        @collection_summons = @collection_summons.by_element(params[:element]) if params[:element]
        @collection_summons = @collection_summons.by_rarity(params[:rarity]) if params[:rarity]

        @collection_summons = @collection_summons.paginate(page: params[:page], per_page: params[:limit] || 50)

        render json: Api::V1::CollectionSummonBlueprint.render(
          @collection_summons,
          root: :collection_summons,
          meta: pagination_meta(@collection_summons)
        )
      end

      def show
        render json: Api::V1::CollectionSummonBlueprint.render(
          @collection_summon,
          view: :full
        )
      end

      def create
        @collection_summon = current_user.collection_summons.build(collection_summon_params)

        if @collection_summon.save
          render json: Api::V1::CollectionSummonBlueprint.render(
            @collection_summon,
            view: :full
          ), status: :created
        else
          render_validation_error_response(@collection_summon)
        end
      end

      def update
        if @collection_summon.update(collection_summon_params)
          render json: Api::V1::CollectionSummonBlueprint.render(
            @collection_summon,
            view: :full
          )
        else
          render_validation_error_response(@collection_summon)
        end
      end

      def destroy
        @collection_summon.destroy
        head :no_content
      end

      private

      def set_collection_summon
        @collection_summon = current_user.collection_summons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('summon', params[:id])
      end

      def collection_summon_params
        params.require(:collection_summon).permit(
          :summon_id, :uncap_level, :transcendence_step
        )
      end
    end
  end
end

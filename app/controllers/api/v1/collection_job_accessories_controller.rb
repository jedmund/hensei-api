module Api
  module V1
    class CollectionJobAccessoriesController < ApiController
      before_action :restrict_access
      before_action :set_collection_job_accessory, only: [:show, :destroy]

      def index
        @collection_accessories = current_user.collection_job_accessories
                                              .includes(job_accessory: :job)

        @collection_accessories = @collection_accessories.by_job(params[:job_id]) if params[:job_id]

        render json: Api::V1::CollectionJobAccessoryBlueprint.render(
          @collection_accessories,
          root: :collection_job_accessories
        )
      end

      def show
        render json: Api::V1::CollectionJobAccessoryBlueprint.render(
          @collection_job_accessory
        )
      end

      def create
        @collection_accessory = current_user.collection_job_accessories
                                            .build(collection_job_accessory_params)

        if @collection_accessory.save
          render json: Api::V1::CollectionJobAccessoryBlueprint.render(
            @collection_accessory
          ), status: :created
        else
          # Check for duplicate job accessory error
          if @collection_accessory.errors[:job_accessory_id].any? { |e| e.include?('already exists') }
            raise CollectionErrors::DuplicateJobAccessory.new(@collection_accessory.job_accessory_id)
          end
          render_validation_error_response(@collection_accessory)
        end
      end

      def destroy
        @collection_job_accessory.destroy
        head :no_content
      end

      private

      def set_collection_job_accessory
        @collection_job_accessory = current_user.collection_job_accessories.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('job accessory', params[:id])
      end

      def collection_job_accessory_params
        params.require(:collection_job_accessory).permit(:job_accessory_id)
      end
    end
  end
end

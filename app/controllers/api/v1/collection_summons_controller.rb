module Api
  module V1
    class CollectionSummonsController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_summon_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy batch batch_destroy import]
      before_action :set_collection_summon_for_write, only: %i[update destroy]

      def index
        @collection_summons = @target_user.collection_summons
                                          .includes(:summon)

        # Apply filters (array_param splits comma-separated values for OR logic)
        @collection_summons = @collection_summons.by_summon(params[:summon_id]) if params[:summon_id]
        @collection_summons = @collection_summons.by_element(array_param(:element)) if params[:element]
        @collection_summons = @collection_summons.by_rarity(array_param(:rarity)) if params[:rarity]

        @collection_summons = @collection_summons.paginate(page: params[:page], per_page: params[:limit] || 50)

        render json: Api::V1::CollectionSummonBlueprint.render(
          @collection_summons,
          root: :summons,
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

      # POST /collection/summons/batch
      # Creates multiple collection summons in a single request
      # Unlike characters, summons can have duplicates (user can own multiple copies)
      def batch
        items = batch_summon_params[:collection_summons] || []
        created = []
        errors = []

        ActiveRecord::Base.transaction do
          items.each_with_index do |item_params, index|
            collection_summon = current_user.collection_summons.build(item_params)

            if collection_summon.save
              created << collection_summon
            else
              errors << {
                index: index,
                summon_id: item_params[:summon_id],
                error: collection_summon.errors.full_messages.join(', ')
              }
            end
          end
        end

        status = errors.any? ? :multi_status : :created

        render json: Api::V1::CollectionSummonBlueprint.render(
          created,
          root: :summons,
          meta: { created: created.size, errors: errors }
        ), status: status
      end

      # DELETE /collection/summons/batch_destroy
      # Deletes multiple collection summons in a single request
      def batch_destroy
        ids = batch_destroy_params[:ids] || []
        deleted_count = current_user.collection_summons.where(id: ids).destroy_all.count

        render json: {
          meta: { deleted: deleted_count }
        }, status: :ok
      end

      # POST /collection/summons/import
      # Imports summons from game JSON data
      #
      # @param data [Hash] Game data containing summon list
      # @param update_existing [Boolean] Whether to update existing summons (default: false)
      def import
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = SummonImportService.new(
          current_user,
          game_data,
          update_existing: import_params[:update_existing] == true
        )

        result = service.import

        status = result.success? ? :created : :multi_status

        render json: {
          success: result.success?,
          created: result.created.size,
          updated: result.updated.size,
          skipped: result.skipped.size,
          errors: result.errors
        }, status: status
      end

      private

      def set_target_user
        @target_user = User.find(params[:user_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: "User not found" }, status: :not_found
      end

      def check_collection_access
        return if @target_user.nil? # Already handled by set_target_user
        unless @target_user.collection_viewable_by?(current_user)
          render json: { error: "You do not have permission to view this collection" }, status: :forbidden
        end
      end

      def set_collection_summon_for_read
        @collection_summon = @target_user.collection_summons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('summon', params[:id])
      end

      def set_collection_summon_for_write
        @collection_summon = current_user.collection_summons.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('summon', params[:id])
      end

      def collection_summon_params
        params.require(:collection_summon).permit(
          :summon_id, :uncap_level, :transcendence_step
        )
      end

      def batch_summon_params
        params.permit(collection_summons: [
          :summon_id, :uncap_level, :transcendence_step
        ])
      end

      def import_params
        {
          update_existing: params[:update_existing],
          data: params[:data]&.to_unsafe_h
        }
      end

      def batch_destroy_params
        params.permit(ids: [])
      end

      def array_param(key)
        params[key]&.to_s&.split(',')
      end
    end
  end
end

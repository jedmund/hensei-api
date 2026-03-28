module Api
  module V1
    class CollectionSummonsController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_summon_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy batch batch_destroy import preview_sync check_conflicts]
      before_action :set_collection_summon_for_write, only: %i[update destroy]

      def index
        if params[:unowned].present?
          return head :forbidden unless current_user && @target_user.id == current_user.id

          owned_ids = @target_user.collection_summons.select(:summon_id).distinct
          @summons = Summon.where.not(id: owned_ids)
                           .includes(:summon_series)

          @summons = @summons.where(element: array_param(:element)) if params[:element]
          @summons = @summons.where(rarity: array_param(:rarity)) if params[:rarity]
          @summons = @summons.where(summon_series_id: array_param(:series)) if params[:series]
          if params[:search].present?
            q = "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%"
            @summons = @summons.where("name_en ILIKE :q OR name_jp ILIKE :q", q: q)
          end

          lang = current_user&.language || 'en'
          @summons = apply_unowned_summon_sort(@summons, params[:sort], lang)
          @summons = @summons.paginate(page: params[:page], per_page: collection_page_size)

          render json: SummonBlueprint.render(
            @summons,
            view: :dates,
            root: :summons,
            meta: pagination_meta(@summons)
          )
          return
        end

        @collection_summons = @target_user.collection_summons
                                          .includes(summon: :summon_series)

        # Apply filters (array_param splits comma-separated values for OR logic)
        @collection_summons = @collection_summons.by_summon(params[:summon_id]) if params[:summon_id]
        @collection_summons = @collection_summons.by_element(array_param(:element)) if params[:element]
        @collection_summons = @collection_summons.by_rarity(array_param(:rarity)) if params[:rarity]
        @collection_summons = @collection_summons.by_series(array_param(:series)) if params[:series]
        @collection_summons = @collection_summons.by_name(params[:search]) if params[:search].present?

        @collection_summons = @collection_summons.sorted_by(params[:sort], current_user&.language || 'en')

        @collection_summons = @collection_summons.paginate(page: params[:page], per_page: collection_page_size)

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
      # @param is_full_inventory [Boolean] Whether this represents the user's complete inventory (default: false)
      # @param reconcile_deletions [Boolean] Whether to delete items not in the import (default: false)
      def import
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = SummonImportService.new(
          current_user,
          game_data,
          update_existing: import_params[:update_existing] == true,
          is_full_inventory: import_params[:is_full_inventory] == true,
          reconcile_deletions: import_params[:reconcile_deletions] == true,
          filter: import_params[:filter],
          conflict_resolutions: import_params[:conflict_resolutions]
        )

        result = service.import

        status = result.success? ? :created : :multi_status

        render json: {
          success: result.success?,
          created: result.created.size,
          updated: result.updated.size,
          skipped: result.skipped.size,
          errors: result.errors,
          reconciliation: result.reconciliation
        }, status: status
      end

      # POST /collection/summons/preview_sync
      # Previews what would be deleted in a full sync operation
      #
      # @param data [Hash] Game data containing summon list
      # @return [JSON] List of items that would be deleted
      def preview_sync
        game_data = import_params[:data]
        filter = import_params[:filter]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = SummonImportService.new(current_user, game_data, filter: filter)
        items_to_delete = service.preview_deletions

        render json: {
          will_delete: items_to_delete.map do |cs|
            {
              id: cs.id,
              game_id: cs.game_id,
              name: cs.summon&.name_en,
              granblue_id: cs.summon&.granblue_id,
              uncap_level: cs.uncap_level,
              transcendence_step: cs.transcendence_step
            }
          end,
          count: items_to_delete.size
        }
      end

      # POST /collection/summons/check_conflicts
      # Checks for items that would conflict with existing null-game_id records
      #
      # @param data [Hash] Game data containing summon list
      # @return [JSON] List of conflicting items
      def check_conflicts
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        items = game_data.is_a?(Array) ? game_data : (game_data['list'] || [])
        conflicts = []

        items.each do |item|
          param = item['param'] || {}
          master = item['master'] || {}

          game_id = param['id']
          next unless game_id.present?

          image_id = param['image_id'].to_s.split('_').first if param['image_id'].present?
          granblue_id = image_id || master['id']
          next unless granblue_id.present?

          resolved_id = SummonIdMapping.resolve(granblue_id)
          summon = Summon.find_by(granblue_id: resolved_id)
          next unless summon

          # Already matched by game_id — no conflict
          next if current_user.collection_summons.exists?(game_id: game_id.to_s)

          # Check for existing record with null game_id for the same summon
          existing = current_user.collection_summons.find_by(summon_id: summon.id, game_id: nil)
          next unless existing

          conflicts << {
            game_id: game_id.to_s,
            granblue_id: granblue_id.to_s,
            name: summon.name_en,
            existing_id: existing.id,
            existing_uncap_level: existing.uncap_level
          }
        end

        render json: { conflicts: conflicts }
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
          is_full_inventory: params[:is_full_inventory],
          reconcile_deletions: params[:reconcile_deletions],
          data: params[:data]&.to_unsafe_h,
          filter: params[:filter]&.to_unsafe_h,
          conflict_resolutions: params[:conflict_resolutions]&.to_unsafe_h
        }
      end

      def batch_destroy_params
        params.permit(ids: [])
      end

      def array_param(key)
        params[key]&.to_s&.split(',')
      end

      def apply_unowned_summon_sort(scope, sort_key, locale)
        name_col = locale == 'ja' ? 'name_jp' : 'name_en'
        case sort_key
        when 'name_asc'
          scope.order(Arel.sql("#{name_col} ASC NULLS LAST"))
        when 'name_desc'
          scope.order(Arel.sql("#{name_col} DESC NULLS LAST"))
        when 'element_asc'
          scope.order(element: :asc)
        when 'element_desc'
          scope.order(element: :desc)
        else
          scope.order(latest_date: :desc, id: :asc)
        end
      end
    end
  end
end

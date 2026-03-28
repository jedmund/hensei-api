module Api
  module V1
    class CollectionCharactersController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_character_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy batch batch_destroy import]
      before_action :set_collection_character_for_write, only: %i[update destroy]

      def index
        if params[:unowned].present?
          return head :forbidden unless current_user && @target_user.id == current_user.id

          owned_ids = @target_user.collection_characters.select(:character_id)
          @characters = Character.where.not(id: owned_ids)
                                 .includes(:character_series_records)

          @characters = @characters.where(element: array_param(:element)) if params[:element]
          @characters = @characters.where(rarity: array_param(:rarity)) if params[:rarity]
          if params[:race]
            races = array_param(:race)
            @characters = @characters.where(race1: races).or(@characters.where(race2: races))
          end
          if params[:proficiency]
            profs = array_param(:proficiency)
            @characters = @characters.where(proficiency1: profs).or(@characters.where(proficiency2: profs))
          end
          @characters = @characters.where(gender: array_param(:gender)) if params[:gender]
          @characters = @characters.by_series(array_param(:series)) if params[:series]
          @characters = @characters.where("name_en ILIKE :q OR name_jp ILIKE :q", q: "%#{ActiveRecord::Base.sanitize_sql_like(params[:search])}%") if params[:search].present?

          lang = current_user&.language || 'en'
          @characters = apply_unowned_character_sort(@characters, params[:sort], lang)
          @characters = @characters.paginate(page: params[:page], per_page: collection_page_size)

          render json: CharacterBlueprint.render(
            @characters,
            view: :dates,
            root: :characters,
            meta: pagination_meta(@characters)
          )
          return
        end

        @collection_characters = @target_user.collection_characters
                                             .includes({ character: :character_series_records }, :awakening)

        # Apply filters (array_param splits comma-separated values for OR logic)
        @collection_characters = @collection_characters.by_element(array_param(:element)) if params[:element]
        @collection_characters = @collection_characters.by_rarity(array_param(:rarity)) if params[:rarity]
        @collection_characters = @collection_characters.by_race(array_param(:race)) if params[:race]
        @collection_characters = @collection_characters.by_proficiency(array_param(:proficiency)) if params[:proficiency]
        @collection_characters = @collection_characters.by_gender(array_param(:gender)) if params[:gender]
        @collection_characters = @collection_characters.by_series(array_param(:series)) if params[:series]
        @collection_characters = @collection_characters.by_name(params[:search]) if params[:search].present?

        # Apply sorting
        @collection_characters = @collection_characters.sorted_by(params[:sort], current_user&.language || 'en')

        # Apply pagination
        @collection_characters = @collection_characters.paginate(page: params[:page], per_page: collection_page_size)

        render json: Api::V1::CollectionCharacterBlueprint.render(
          @collection_characters,
          root: :characters,
          meta: pagination_meta(@collection_characters)
        )
      end

      def show
        render json: Api::V1::CollectionCharacterBlueprint.render(
          @collection_character,
          view: :full
        )
      end

      def create
        @collection_character = current_user.collection_characters.build(collection_character_params)

        if @collection_character.save
          render json: Api::V1::CollectionCharacterBlueprint.render(
            @collection_character,
            view: :full
          ), status: :created
        else
          # Check for duplicate character error
          if @collection_character.errors[:character_id].any? { |e| e.include?('already exists') }
            raise CollectionErrors::DuplicateCharacter.new(@collection_character.character_id)
          end
          render_validation_error_response(@collection_character)
        end
      end

      def update
        if @collection_character.update(collection_character_params)
          render json: Api::V1::CollectionCharacterBlueprint.render(
            @collection_character,
            view: :full
          )
        else
          render_validation_error_response(@collection_character)
        end
      end

      def destroy
        @collection_character.destroy
        head :no_content
      end

      # POST /collection/characters/batch
      # Creates multiple collection characters in a single request
      def batch
        items = batch_character_params[:collection_characters] || []
        created = []
        skipped = []
        errors = []

        ActiveRecord::Base.transaction do
          items.each_with_index do |item_params, index|
            # Check if already exists (skip duplicates)
            if current_user.collection_characters.exists?(character_id: item_params[:character_id])
              skipped << { index: index, character_id: item_params[:character_id], reason: 'already_exists' }
              next
            end

            collection_character = current_user.collection_characters.build(item_params)

            if collection_character.save
              created << collection_character
            else
              errors << {
                index: index,
                character_id: item_params[:character_id],
                error: collection_character.errors.full_messages.join(', ')
              }
            end
          end
        end

        status = errors.any? ? :multi_status : :created

        render json: Api::V1::CollectionCharacterBlueprint.render(
          created,
          root: :characters,
          meta: { created: created.size, skipped: skipped.size, skipped_items: skipped, errors: errors }
        ), status: status
      end

      # DELETE /collection/characters/batch_destroy
      # Deletes multiple collection characters in a single request
      def batch_destroy
        ids = batch_destroy_params[:ids] || []
        deleted_count = current_user.collection_characters.where(id: ids).destroy_all.count

        render json: {
          meta: { deleted: deleted_count }
        }, status: :ok
      end

      # POST /collection/characters/import
      # Imports characters from game JSON data
      #
      # @param data [Hash] Game data containing character list
      # @param update_existing [Boolean] Whether to update existing characters (default: false)
      def import
        game_data = import_params[:data]

        unless game_data.present?
          return render json: { error: 'No data provided' }, status: :bad_request
        end

        service = CharacterImportService.new(
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

      def set_collection_character_for_read
        @collection_character = @target_user.collection_characters.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('character', params[:id])
      end

      def set_collection_character_for_write
        @collection_character = current_user.collection_characters.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise CollectionErrors::CollectionItemNotFound.new('character', params[:id])
      end

      def collection_character_params
        params.require(:collection_character).permit(
          :character_id, :uncap_level, :transcendence_step, :perpetuity,
          :awakening_id, :awakening_level,
          ring1: %i[modifier strength],
          ring2: %i[modifier strength],
          ring3: %i[modifier strength],
          ring4: %i[modifier strength],
          earring: %i[modifier strength]
        )
      end

      def batch_character_params
        params.permit(collection_characters: [
          :character_id, :uncap_level, :transcendence_step, :perpetuity,
          :awakening_id, :awakening_level,
          ring1: %i[modifier strength],
          ring2: %i[modifier strength],
          ring3: %i[modifier strength],
          ring4: %i[modifier strength],
          earring: %i[modifier strength]
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

      def apply_unowned_character_sort(scope, sort_key, locale)
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
        when 'proficiency_asc'
          scope.order(proficiency1: :asc)
        when 'proficiency_desc'
          scope.order(proficiency1: :desc)
        else
          scope.order(latest_date: :desc, id: :asc)
        end
      end
    end
  end
end

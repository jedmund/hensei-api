module Api
  module V1
    class CollectionCharactersController < ApiController
      # Read actions: look up user from params, check privacy
      before_action :set_target_user, only: %i[index show]
      before_action :check_collection_access, only: %i[index show]
      before_action :set_collection_character_for_read, only: %i[show]

      # Write actions: require auth, use current_user
      before_action :restrict_access, only: %i[create update destroy]
      before_action :set_collection_character_for_write, only: %i[update destroy]

      def index
        @collection_characters = @target_user.collection_characters
                                             .includes(:character, :awakening)

        # Apply filters
        @collection_characters = @collection_characters.by_element(params[:element]) if params[:element]
        @collection_characters = @collection_characters.by_rarity(params[:rarity]) if params[:rarity]
        @collection_characters = @collection_characters.by_race(params[:race]) if params[:race]
        @collection_characters = @collection_characters.by_proficiency(params[:proficiency]) if params[:proficiency]
        @collection_characters = @collection_characters.by_gender(params[:gender]) if params[:gender]

        # Apply pagination
        @collection_characters = @collection_characters.paginate(page: params[:page], per_page: params[:limit] || 50)

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
    end
  end
end

# frozen_string_literal: true

module Api
  module V1
    class CharactersController < Api::V1::ApiController
      include IdResolvable

      before_action :set, only: %i[show related download_images download_status]
      before_action :ensure_editor_role, only: %i[create validate download_images]

      # GET /characters/:id
      def show
        render json: CharacterBlueprint.render(@character, view: :full)
      end

      # GET /characters/:id/related
      def related
        return render json: [] unless @character.character_id

        related = Character.where(character_id: @character.character_id)
                           .where.not(id: @character.id)
        render json: CharacterBlueprint.render(related)
      end

      # POST /characters
      # Creates a new character record
      def create
        character = Character.new(character_params)

        if character.save
          render json: CharacterBlueprint.render(character, view: :full), status: :created
        else
          render_validation_error_response(character)
        end
      end

      # GET /characters/validate/:granblue_id
      # Validates that a granblue_id has accessible images on Granblue servers
      def validate
        granblue_id = params[:granblue_id]
        validator = CharacterImageValidator.new(granblue_id)

        response_data = {
          granblue_id: granblue_id,
          exists_in_db: validator.exists_in_db?
        }

        if validator.valid?
          render json: response_data.merge(
            valid: true,
            image_urls: validator.image_urls
          )
        else
          render json: response_data.merge(
            valid: false,
            error: validator.error_message
          )
        end
      end

      # POST /characters/:id/download_images
      # Triggers async image download for a character
      def download_images
        # Queue the download job
        DownloadCharacterImagesJob.perform_later(
          @character.id,
          force: params.dig(:options, :force) == true,
          size: params.dig(:options, :size) || 'all'
        )

        # Set initial status
        DownloadCharacterImagesJob.update_status(
          @character.id,
          'queued',
          progress: 0,
          images_downloaded: 0
        )

        render json: {
          status: 'queued',
          character_id: @character.id,
          granblue_id: @character.granblue_id,
          message: 'Image download job has been queued'
        }, status: :accepted
      end

      # GET /characters/:id/download_status
      # Returns the status of an image download job
      def download_status
        status = DownloadCharacterImagesJob.status(@character.id)

        render json: status.merge(
          character_id: @character.id,
          granblue_id: @character.granblue_id
        )
      end

      private

      def set
        @character = find_by_any_id(Character, params[:id])
        render_not_found_response('character') unless @character
      end

      # Ensures the current user has editor role (role >= 7)
      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[CHARACTERS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def character_params
        params.require(:character).permit(
          :granblue_id, :name_en, :name_jp, :rarity, :element,
          :proficiency1, :proficiency2, :gender, :race1, :race2,
          :flb, :ulb, :special,
          :min_hp, :max_hp, :max_hp_flb, :max_hp_ulb,
          :min_atk, :max_atk, :max_atk_flb, :max_atk_ulb,
          :base_da, :base_ta, :ougi_ratio, :ougi_ratio_flb,
          :release_date, :flb_date, :ulb_date,
          :wiki_en, :wiki_ja, :gamewith, :kamigame,
          nicknames_en: [], nicknames_jp: [], character_id: []
        )
      end
    end
  end
end

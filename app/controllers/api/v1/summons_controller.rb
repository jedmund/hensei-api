# frozen_string_literal: true

module Api
  module V1
    class SummonsController < Api::V1::ApiController
      include IdResolvable

      before_action :set, only: %i[show download_images download_status]
      before_action :ensure_editor_role, only: %i[create validate download_images]

      # GET /summons/:id
      def show
        render json: SummonBlueprint.render(@summon, view: :full)
      end

      # POST /summons
      # Creates a new summon record
      def create
        summon = Summon.new(summon_params)

        if summon.save
          render json: SummonBlueprint.render(summon, view: :full), status: :created
        else
          render_validation_error_response(summon)
        end
      end

      # GET /summons/validate/:granblue_id
      # Validates that a granblue_id has accessible images on Granblue servers
      def validate
        granblue_id = params[:granblue_id]
        validator = SummonImageValidator.new(granblue_id)

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

      # POST /summons/:id/download_images
      # Triggers async image download for a summon
      def download_images
        # Queue the download job
        DownloadSummonImagesJob.perform_later(
          @summon.id,
          force: params.dig(:options, :force) == true,
          size: params.dig(:options, :size) || 'all'
        )

        # Set initial status
        DownloadSummonImagesJob.update_status(
          @summon.id,
          'queued',
          progress: 0,
          images_downloaded: 0
        )

        render json: {
          status: 'queued',
          summon_id: @summon.id,
          granblue_id: @summon.granblue_id,
          message: 'Image download job has been queued'
        }, status: :accepted
      end

      # GET /summons/:id/download_status
      # Returns the status of an image download job
      def download_status
        status = DownloadSummonImagesJob.status(@summon.id)

        render json: status.merge(
          summon_id: @summon.id,
          granblue_id: @summon.granblue_id
        )
      end

      private

      def set
        @summon = find_by_any_id(Summon, params[:id])
        render_not_found_response('summon') unless @summon
      end

      # Ensures the current user has editor role (role >= 7)
      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[SUMMONS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def summon_params
        params.require(:summon).permit(
          :granblue_id, :name_en, :name_jp, :summon_id, :rarity, :element, :series,
          :flb, :ulb, :transcendence, :subaura, :limit,
          :min_hp, :max_hp, :max_hp_flb, :max_hp_ulb, :max_hp_xlb,
          :min_atk, :max_atk, :max_atk_flb, :max_atk_ulb, :max_atk_xlb,
          :max_level,
          :release_date, :flb_date, :ulb_date, :transcendence_date,
          :wiki_en, :wiki_ja, :gamewith, :kamigame,
          nicknames_en: [], nicknames_jp: []
        )
      end
    end
  end
end

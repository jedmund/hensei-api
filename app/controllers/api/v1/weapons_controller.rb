# frozen_string_literal: true

module Api
  module V1
    class WeaponsController < Api::V1::ApiController
      include IdResolvable

      before_action :set, only: %i[show download_images download_status]
      before_action :ensure_editor_role, only: %i[create validate download_images]

      # GET /weapons/:id
      def show
        render json: WeaponBlueprint.render(@weapon, view: :full)
      end

      # POST /weapons
      # Creates a new weapon record
      def create
        weapon = Weapon.new(weapon_params)

        if weapon.save
          render json: WeaponBlueprint.render(weapon, view: :full), status: :created
        else
          render_validation_error_response(weapon)
        end
      end

      # GET /weapons/validate/:granblue_id
      # Validates that a granblue_id has accessible images on Granblue servers
      def validate
        granblue_id = params[:granblue_id]
        validator = WeaponImageValidator.new(granblue_id)

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

      # POST /weapons/:id/download_images
      # Triggers async image download for a weapon
      def download_images
        # Queue the download job
        DownloadWeaponImagesJob.perform_later(
          @weapon.id,
          force: params.dig(:options, :force) == true,
          size: params.dig(:options, :size) || 'all'
        )

        # Set initial status
        DownloadWeaponImagesJob.update_status(
          @weapon.id,
          'queued',
          progress: 0,
          images_downloaded: 0
        )

        render json: {
          status: 'queued',
          weapon_id: @weapon.id,
          granblue_id: @weapon.granblue_id,
          message: 'Image download job has been queued'
        }, status: :accepted
      end

      # GET /weapons/:id/download_status
      # Returns the status of an image download job
      def download_status
        status = DownloadWeaponImagesJob.status(@weapon.id)

        render json: status.merge(
          weapon_id: @weapon.id,
          granblue_id: @weapon.granblue_id
        )
      end

      private

      def set
        @weapon = find_by_any_id(Weapon, params[:id])
        render_not_found_response('weapon') unless @weapon
      end

      # Ensures the current user has editor role (role >= 7)
      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[WEAPONS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end

      def weapon_params
        params.require(:weapon).permit(
          :granblue_id, :name_en, :name_jp, :rarity, :element, :proficiency, :series, :new_series,
          :flb, :ulb, :transcendence, :extra, :limit, :ax,
          :min_hp, :max_hp, :max_hp_flb, :max_hp_ulb,
          :min_atk, :max_atk, :max_atk_flb, :max_atk_ulb,
          :max_level, :max_skill_level, :max_awakening_level,
          :release_date, :flb_date, :ulb_date, :transcendence_date,
          :wiki_en, :wiki_ja, :gamewith, :kamigame,
          :recruits,
          nicknames_en: [], nicknames_jp: []
        )
      end
    end
  end
end

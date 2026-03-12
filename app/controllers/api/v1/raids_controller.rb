# frozen_string_literal: true

module Api
  module V1
    class RaidsController < Api::V1::ApiController
      before_action :set_raid, only: %i[show update destroy download_image download_images download_status]
      before_action :ensure_editor_role, only: %i[create update destroy download_image download_images]

      # GET /raids
      def index
        raids = Raid.includes(:group)
        raids = apply_filters(raids)
        raids = raids.ordered

        render json: RaidBlueprint.render(raids, view: :nested)
      end

      # GET /raids/:id
      def show
        if @raid
          render json: RaidBlueprint.render(@raid, view: :full)
        else
          render json: { error: 'Raid not found' }, status: :not_found
        end
      end

      # POST /raids
      def create
        raid = Raid.new(raid_params)

        if raid.save
          render json: RaidBlueprint.render(raid, view: :full), status: :created
        else
          render_validation_error_response(raid)
        end
      end

      # PATCH/PUT /raids/:id
      def update
        if @raid.update(raid_params)
          render json: RaidBlueprint.render(@raid, view: :full)
        else
          render_validation_error_response(@raid)
        end
      end

      # DELETE /raids/:id
      def destroy
        if Party.where(raid_id: @raid.id).exists?
          render json: ErrorBlueprint.render(nil, error: {
            message: 'Cannot delete raid with associated parties',
            code: 'has_dependencies'
          }), status: :unprocessable_entity
        else
          @raid.destroy!
          head :no_content
        end
      end

      # POST /raids/:id/download_image
      # Synchronously downloads a single image for a raid
      def download_image
        size = params[:size]
        force = params[:force] == true

        valid_sizes = Granblue::Downloaders::RaidDownloader::SIZES
        unless valid_sizes.include?(size)
          return render json: { error: "Invalid size. Must be one of: #{valid_sizes.join(', ')}" }, status: :unprocessable_entity
        end

        # Check if the required ID exists
        if size == 'icon' && @raid.enemy_id.blank?
          return render json: { error: 'Raid has no enemy_id configured' }, status: :unprocessable_entity
        end
        if size == 'thumbnail' && @raid.summon_id.blank?
          return render json: { error: 'Raid has no summon_id configured' }, status: :unprocessable_entity
        end
        if %w[lobby background].include?(size) && @raid.quest_id.blank?
          return render json: { error: 'Raid has no quest_id configured' }, status: :unprocessable_entity
        end

        begin
          downloader = Granblue::Downloaders::RaidDownloader.new(
            @raid,
            storage: :s3,
            force: force,
            verbose: true
          )

          downloader.download(size)

          render json: {
            success: true,
            raid_id: @raid.id,
            slug: @raid.slug,
            size: size,
            message: 'Image downloaded successfully'
          }
        rescue StandardError => e
          Rails.logger.error "[RAIDS] Image download error for #{@raid.id}: #{e.message}"
          render json: { success: false, error: e.message }, status: :internal_server_error
        end
      end

      # POST /raids/:id/download_images
      # Triggers async image download for a raid
      def download_images
        DownloadRaidImagesJob.perform_later(
          @raid.id,
          force: params.dig(:options, :force) == true,
          size: params.dig(:options, :size) || 'all'
        )

        DownloadRaidImagesJob.update_status(
          @raid.id,
          'queued',
          progress: 0,
          images_downloaded: 0
        )

        render json: {
          status: 'queued',
          raid_id: @raid.id,
          slug: @raid.slug,
          message: 'Image download job has been queued'
        }, status: :accepted
      end

      # GET /raids/:id/download_status
      # Returns the status of an image download job
      def download_status
        status = DownloadRaidImagesJob.status(@raid.id)

        render json: status.merge(
          raid_id: @raid.id,
          slug: @raid.slug
        )
      end

      # GET /raids/groups (legacy endpoint)
      def groups
        render json: RaidGroupBlueprint.render(RaidGroup.includes(raids: :group).ordered, view: :full)
      end

      # Legacy alias for index
      def all
        index
      end

      private

      def set_raid
        @raid = Raid.find_by(slug: params[:id]) || Raid.find_by(id: params[:id])
      end

      def raid_params
        params.require(:raid).permit(:name_en, :name_jp, :level, :element, :slug, :group_id, :enemy_id, :summon_id, :quest_id, :extra, :player_count)
      end

      def apply_filters(scope)
        scope = scope.by_element(filter_params[:element]) if filter_params[:element].present?
        scope = scope.by_group(filter_params[:group_id]) if filter_params[:group_id].present?
        scope = scope.by_difficulty(filter_params[:difficulty]) if filter_params[:difficulty].present?
        scope = scope.by_hl(filter_params[:hl]) if filter_params[:hl].present?
        scope = scope.by_extra(filter_params[:extra]) if filter_params[:extra].present?
        scope = scope.with_guidebooks if filter_params[:guidebooks] == 'true'
        scope
      end

      def filter_params
        params.except(:controller, :action, :format, :raid).permit(:element, :group_id, :difficulty, :hl, :extra, :guidebooks)
      end

      def ensure_editor_role
        return if current_user&.role && current_user.role >= 7

        Rails.logger.warn "[RAIDS] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized - Editor role required' }, status: :unauthorized
      end
    end
  end
end

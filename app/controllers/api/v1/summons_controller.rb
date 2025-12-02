# frozen_string_literal: true

module Api
  module V1
    class SummonsController < Api::V1::ApiController
      include IdResolvable
      include BatchPreviewable

      before_action :set, only: %i[show download_image download_images download_status update raw fetch_wiki]
      before_action :ensure_editor_role, only: %i[create update validate download_image download_images fetch_wiki batch_preview]

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

      # PATCH/PUT /summons/:id
      # Updates an existing summon record
      def update
        if @summon.update(summon_params)
          render json: SummonBlueprint.render(@summon, view: :full)
        else
          render_validation_error_response(@summon)
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

      # POST /summons/:id/download_image
      # Synchronously downloads a single image for a summon
      def download_image
        size = params[:size]
        transformation = params[:transformation]
        force = params[:force] == true

        # Validate size
        valid_sizes = Granblue::Downloaders::SummonDownloader::SIZES
        unless valid_sizes.include?(size)
          return render json: { error: "Invalid size. Must be one of: #{valid_sizes.join(', ')}" }, status: :unprocessable_entity
        end

        # Validate transformation for summons (none, 02, 03, 04)
        valid_transformations = [nil, '', '02', '03', '04']
        if transformation.present? && !valid_transformations.include?(transformation)
          return render json: { error: 'Invalid transformation. Must be one of: 02, 03, 04 (or empty for base)' }, status: :unprocessable_entity
        end

        # Build variant ID - summons don't have suffix for base
        variant_id = transformation.present? ? "#{@summon.granblue_id}_#{transformation}" : @summon.granblue_id

        begin
          downloader = Granblue::Downloaders::SummonDownloader.new(
            @summon.granblue_id,
            storage: :s3,
            force: force,
            verbose: true
          )

          # Call the download_variant method directly for a single variant/size
          downloader.send(:download_variant, variant_id, size)

          render json: {
            success: true,
            summon_id: @summon.id,
            granblue_id: @summon.granblue_id,
            size: size,
            transformation: transformation,
            message: 'Image downloaded successfully'
          }
        rescue StandardError => e
          Rails.logger.error "[SUMMONS] Image download error for #{@summon.id}: #{e.message}"
          render json: { success: false, error: e.message }, status: :internal_server_error
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

      # GET /summons/:id/raw
      # Returns raw wiki and game data for database viewing
      def raw
        render json: SummonBlueprint.render(@summon, view: :raw)
      end

      # POST /summons/batch_preview
      # Fetches wiki data and suggestions for multiple wiki page names
      def batch_preview
        wiki_pages = params[:wiki_pages]

        unless wiki_pages.is_a?(Array) && wiki_pages.any?
          return render json: { error: 'wiki_pages must be a non-empty array' }, status: :unprocessable_entity
        end

        # Limit to 10 pages
        wiki_pages = wiki_pages.first(10)

        results = wiki_pages.map do |wiki_page|
          process_wiki_preview(wiki_page, :summon)
        end

        render json: { results: results }
      end

      # POST /summons/:id/fetch_wiki
      # Fetches and stores wiki data for this summon
      def fetch_wiki
        unless @summon.wiki_en.present?
          return render json: { error: 'No wiki page configured for this summon' }, status: :unprocessable_entity
        end

        begin
          wiki_text = Granblue::Parsers::Wiki.new.fetch(@summon.wiki_en)

          # Handle redirects
          redirect_match = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/)
          if redirect_match
            redirect_target = redirect_match[1]
            @summon.update!(wiki_en: redirect_target)
            wiki_text = Granblue::Parsers::Wiki.new.fetch(redirect_target)
          end

          @summon.update!(wiki_raw: wiki_text)
          render json: SummonBlueprint.render(@summon, view: :raw)
        rescue Granblue::WikiError => e
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        rescue StandardError => e
          Rails.logger.error "[SUMMONS] Wiki fetch error for #{@summon.id}: #{e.message}"
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        end
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
          nicknames_en: [], nicknames_jp: [], promotions: []
        )
      end
    end
  end
end

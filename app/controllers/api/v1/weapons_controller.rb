# frozen_string_literal: true

module Api
  module V1
    class WeaponsController < Api::V1::ApiController
      include IdResolvable
      include BatchPreviewable

      before_action :set, only: %i[show download_image download_images download_status update raw fetch_wiki]
      before_action :ensure_editor_role, only: %i[create update validate download_image download_images fetch_wiki batch_preview]

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

      # PATCH/PUT /weapons/:id
      # Updates an existing weapon record
      def update
        if @weapon.update(weapon_params)
          render json: WeaponBlueprint.render(@weapon, view: :full)
        else
          render_validation_error_response(@weapon)
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

      # POST /weapons/:id/download_image
      # Synchronously downloads a single image for a weapon
      def download_image
        size = params[:size]
        transformation = params[:transformation]
        force = params[:force] == true

        # Validate size
        valid_sizes = Granblue::Downloaders::WeaponDownloader::SIZES
        unless valid_sizes.include?(size)
          return render json: { error: "Invalid size. Must be one of: #{valid_sizes.join(', ')}" }, status: :unprocessable_entity
        end

        # Validate transformation for weapons (none, 02, 03)
        valid_transformations = [nil, '', '02', '03']
        if transformation.present? && !valid_transformations.include?(transformation)
          return render json: { error: 'Invalid transformation. Must be one of: 02, 03 (or empty for base)' }, status: :unprocessable_entity
        end

        # Build variant ID - weapons don't have suffix for base
        variant_id = transformation.present? ? "#{@weapon.granblue_id}_#{transformation}" : @weapon.granblue_id

        begin
          downloader = Granblue::Downloaders::WeaponDownloader.new(
            @weapon.granblue_id,
            storage: :s3,
            force: force,
            verbose: true
          )

          # Call the download_variant method directly for a single variant/size
          downloader.send(:download_variant, variant_id, size)

          render json: {
            success: true,
            weapon_id: @weapon.id,
            granblue_id: @weapon.granblue_id,
            size: size,
            transformation: transformation,
            message: 'Image downloaded successfully'
          }
        rescue StandardError => e
          Rails.logger.error "[WEAPONS] Image download error for #{@weapon.id}: #{e.message}"
          render json: { success: false, error: e.message }, status: :internal_server_error
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

      # GET /weapons/:id/raw
      # Returns raw wiki and game data for database viewing
      def raw
        render json: WeaponBlueprint.render(@weapon, view: :raw)
      end

      # POST /weapons/batch_preview
      # Fetches wiki data and suggestions for multiple wiki page names
      def batch_preview
        wiki_pages = params[:wiki_pages]
        wiki_data = params[:wiki_data] || {}

        unless wiki_pages.is_a?(Array) && wiki_pages.any?
          return render json: { error: 'wiki_pages must be a non-empty array' }, status: :unprocessable_entity
        end

        # Limit to 10 pages
        wiki_pages = wiki_pages.first(10)

        results = wiki_pages.map do |wiki_page|
          process_wiki_preview(wiki_page, :weapon, wiki_raw: wiki_data[wiki_page])
        end

        render json: { results: results }
      end

      # POST /weapons/:id/fetch_wiki
      # Fetches and stores wiki data for this weapon
      def fetch_wiki
        unless @weapon.wiki_en.present?
          return render json: { error: 'No wiki page configured for this weapon' }, status: :unprocessable_entity
        end

        begin
          wiki_text = Granblue::Parsers::Wiki.new.fetch(@weapon.wiki_en)

          # Handle redirects
          redirect_match = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/)
          if redirect_match
            redirect_target = redirect_match[1]
            @weapon.update!(wiki_en: redirect_target)
            wiki_text = Granblue::Parsers::Wiki.new.fetch(redirect_target)
          end

          @weapon.update!(wiki_raw: wiki_text)
          render json: WeaponBlueprint.render(@weapon, view: :raw)
        rescue Granblue::WikiError => e
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        rescue StandardError => e
          Rails.logger.error "[WEAPONS] Wiki fetch error for #{@weapon.id}: #{e.message}"
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        end
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
          nicknames_en: [], nicknames_jp: [], promotions: []
        )
      end
    end
  end
end

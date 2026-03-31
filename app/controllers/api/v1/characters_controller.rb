# frozen_string_literal: true

module Api
  module V1
    class CharactersController < Api::V1::ApiController
      include IdResolvable
      include BatchPreviewable

      before_action :set, only: %i[show related download_image download_images download_status update raw fetch_wiki]
      before_action :ensure_editor_role, only: %i[create update validate download_image download_images fetch_wiki batch_preview]

      # GET /characters/:id
      def show
        render json: CharacterBlueprint.render(@character, view: :with_recruitment)
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

      # PATCH/PUT /characters/:id
      # Updates an existing character record
      def update
        if @character.update(character_params)
          render json: CharacterBlueprint.render(@character, view: :full)
        else
          render_validation_error_response(@character)
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

      # POST /characters/:id/download_image
      # Synchronously downloads a single image for a character
      def download_image
        size = params[:size]
        transformation = params[:transformation]
        element = params[:element].present? ? params[:element].to_i : nil
        gender = params[:gender].present? ? params[:gender].to_i : 0
        force = params[:force] == true

        # Validate size
        valid_sizes = Granblue::Downloaders::CharacterDownloader::SIZES
        unless valid_sizes.include?(size)
          return render json: { error: "Invalid size. Must be one of: #{valid_sizes.join(', ')}" }, status: :unprocessable_entity
        end

        # Validate transformation for characters (01, 02, 03, 04, or style for style swaps)
        valid_transformations = %w[01 02 03 04 style]
        if transformation.present? && !valid_transformations.include?(transformation)
          return render json: { error: "Invalid transformation. Must be one of: #{valid_transformations.join(', ')}" }, status: :unprocessable_entity
        end

        # Validate element for null-element characters
        if element.present? && !(1..6).cover?(element)
          return render json: { error: 'Invalid element. Must be 1-6' }, status: :unprocessable_entity
        end

        # Validate gender (0=Gran, 1=Djeeta)
        unless [0, 1].include?(gender)
          return render json: { error: 'Invalid gender. Must be 0 (Gran) or 1 (Djeeta)' }, status: :unprocessable_entity
        end

        begin
          downloader = Granblue::Downloaders::CharacterDownloader.new(
            @character.granblue_id,
            storage: :s3,
            force: force,
            verbose: true
          )

          if transformation == 'style' || (@character.style_swap? && transformation.blank?)
            # Style swap: fetch from _st2 URL and store as _style
            downloader.send(:download_style_variant, size)
          else
            pose = transformation.present? ? transformation : '01'
            variant_id = "#{@character.granblue_id}_#{pose}"

            # Add element suffix for null-element characters
            variant_id = "#{variant_id}_0#{element}" if element.present?

            # Add gender suffix when requested
            variant_id = "#{variant_id}_#{gender}" if params[:gender].present?

            downloader.send(:download_variant, variant_id, size)
          end

          render json: {
            success: true,
            character_id: @character.id,
            granblue_id: @character.granblue_id,
            size: size,
            transformation: transformation,
            element: element,
            message: 'Image downloaded successfully'
          }
        rescue StandardError => e
          Rails.logger.error "[CHARACTERS] Image download error for #{@character.id}: #{e.message}"
          render json: { success: false, error: e.message }, status: :internal_server_error
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

      # GET /characters/:id/raw
      # Returns raw wiki and game data for database viewing
      def raw
        render json: CharacterBlueprint.render(@character, view: :raw)
      end

      # POST /characters/batch_preview
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
          process_wiki_preview(wiki_page, :character, wiki_raw: wiki_data[wiki_page])
        end

        render json: { results: results }
      end

      # POST /characters/:id/fetch_wiki
      # Fetches and stores wiki data for this character
      def fetch_wiki
        unless @character.wiki_en.present?
          return render json: { error: 'No wiki page configured for this character' }, status: :unprocessable_entity
        end

        begin
          wiki_text = Granblue::Parsers::Wiki.new.fetch(@character.wiki_en)

          # Handle redirects
          redirect_match = wiki_text.match(/#REDIRECT \[\[(.*?)\]\]/)
          if redirect_match
            redirect_target = redirect_match[1]
            @character.update!(wiki_en: redirect_target)
            wiki_text = Granblue::Parsers::Wiki.new.fetch(redirect_target)
          end

          @character.update!(wiki_raw: wiki_text)
          render json: CharacterBlueprint.render(@character, view: :raw)
        rescue Granblue::WikiError => e
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        rescue StandardError => e
          Rails.logger.error "[CHARACTERS] Wiki fetch error for #{@character.id}: #{e.message}"
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        end
      end

      private

      def set
        if params[:style_swap] == 'true' && !uuid_format?(params[:id])
          @character = Character.where(granblue_id: params[:id], style_swap: true).first
        else
          @character = find_by_any_id(Character, params[:id])
        end
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
          :flb, :transcendence, :special, :season, :style_swap, :style_name_en, :style_name_jp,
          :min_hp, :max_hp, :max_hp_flb, :max_hp_transcendence,
          :min_atk, :max_atk, :max_atk_flb, :max_atk_transcendence,
          :base_da, :base_ta, :ougi_ratio, :ougi_ratio_flb,
          :release_date, :flb_date, :transcendence_date,
          :wiki_en, :wiki_ja, :wiki_raw, :gamewith, :kamigame,
          nicknames_en: [], nicknames_jp: [], character_id: [], series: []
        )
      end
    end
  end
end

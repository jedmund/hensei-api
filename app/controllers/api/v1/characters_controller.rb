# frozen_string_literal: true

module Api
  module V1
    class CharactersController < Api::V1::ApiController
      include IdResolvable
      include BatchPreviewable
      include ImageDownloadOptions

      before_action :set, only: %i[show related download_image download_images download_status update raw fetch_wiki reparse]
      before_action :ensure_editor_role, only: %i[create update validate download_image download_images download_status fetch_wiki reparse
                                                  batch_preview raw]

      # GET /characters/:id
      def show
        render json: CharacterBlueprint.render(@character, view: :with_recruitment, source_dates: true)
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
        character = Character.new(with_wiki_fetch_date(character_params))

        if character.save
          render json: CharacterBlueprint.render(character, view: :full, source_dates: true), status: :created
        else
          render_validation_error_response(character)
        end
      end

      # PATCH/PUT /characters/:id
      # Updates an existing character record
      def update
        if @character.update(with_wiki_fetch_date(update_params, @character))
          render json: CharacterBlueprint.render(@character, view: :full, source_dates: true)
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
        size = validated_download_size(params[:size], Granblue::Downloaders::CharacterDownloader::SIZES)
        return unless size

        transformation = params[:transformation]
        element = params[:element].present? ? params[:element].to_i : nil
        gender = params[:gender].present? ? params[:gender].to_i : 0
        force = params[:force] == true

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
            storage_id = "#{@character.granblue_id}_#{pose}"
            storage_id = "#{storage_id}_0#{element}" if element.present?
            storage_id = "#{storage_id}_#{gender}" if params[:gender].present?

            if element.present?
              # Element variants need remapping: internal element ID for storage, GBF ID for download
              gbf_element = GranblueEnums::INTERNAL_TO_GBF_ELEMENT[element] || element
              source_id = "#{@character.granblue_id}_#{pose}_0#{gbf_element}"
              source_id = "#{source_id}_#{gender}" if params[:gender].present?
              downloader.send(:download_remapped_variant, source_id, storage_id, size)
            else
              downloader.send(:download_variant, storage_id, size)
            end
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
        size = validated_download_size(params.dig(:options, :size) || 'all',
                                       Granblue::Downloaders::CharacterDownloader::SIZES, allow_all: true)
        return unless size

        # Queue the download job
        DownloadCharacterImagesJob.perform_later(
          @character.id,
          force: params.dig(:options, :force) == true,
          size: size
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
          Granblue::WikiFetcher.new.fetch_and_store(@character)
          render json: CharacterBlueprint.render(@character, view: :raw)
        rescue Granblue::WikiError => e
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        rescue StandardError => e
          Rails.logger.error "[CHARACTERS] Wiki fetch error for #{@character.id}: #{e.message}"
          render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
        end
      end

      # POST /characters/:id/reparse
      # Body (contract C6): { refetch, refetch_jp, preview, preview_token }.
      #   preview: true   fetches what's asked and builds in shadow mode; writes nothing and
      #                   returns a preview_token that keeps the fetched text for 30 minutes.
      #   preview_token   writes exactly the previewed text and builds, without fetching.
      #   neither         fetches what's asked (refetch=true still works as a query param),
      #                   then writes and builds.
      # → { refresh: <C6 refresh>, character: <:full character when written, else null> }
      def reparse
        result =
          if boolean_param(:preview)
            CharacterSkills::Refresh.preview(@character, user: current_user, refetch: boolean_param(:refetch),
                                                         refetch_jp: boolean_param(:refetch_jp))
          elsif params[:preview_token].present?
            CharacterSkills::Refresh.apply_preview(@character, user: current_user, token: params[:preview_token].to_s)
          else
            CharacterSkills::Refresh.reparse(@character, refetch: boolean_param(:refetch),
                                                         refetch_jp: boolean_param(:refetch_jp))
          end
        render json: { refresh: result, character: result[:written] ? full_character : nil }
      rescue CharacterSkills::Refresh::PreviewExpired => e
        render json: { error: 'preview_expired', message: e.message }, status: :unprocessable_entity
      rescue Granblue::WikiFetcher::MissingPageError, CharacterSkills::Refresh::BuildRefused => e
        render json: { error: e.message, message: e.message }, status: :unprocessable_entity
      rescue Granblue::WikiError => e
        render json: { error: "Failed to fetch wiki data: #{e.message}" }, status: :bad_gateway
      rescue StandardError => e
        Rails.logger.error "[CHARACTERS] Reparse error for #{@character.id}: #{e.class}: #{e.message}"
        render json: { error: "Failed to re-parse: #{e.message}" }, status: :internal_server_error
      end

      private

      def boolean_param(key)
        ActiveModel::Type::Boolean.new.cast(params[key]) || false
      end

      def full_character
        character = Character.find(@character.id)
        ActiveRecord::Associations::Preloader.new(records: [character], associations: Character::SKILL_GRAPH_PRELOAD).call
        CharacterBlueprint.render_as_hash(character, view: :full, source_dates: true)
      end

      def set
        if params[:style_swap] == 'true' && !uuid_format?(params[:id])
          @character = Character.where(granblue_id: params[:id], style_swap: true).first
        else
          @character = find_by_any_id(Character, params[:id])
        end
        return render_not_found_response('character') unless @character

        # Preload the skill graph so the :full view's skills/skill_links don't N+1.
        ActiveRecord::Associations::Preloader.new(
          records: [@character], associations: Character::SKILL_GRAPH_PRELOAD
        ).call
      end

      # The edit form sends back the wikitext it loaded, so a blank wiki_raw means
      # it failed to load, not a deliberate clear: keep the stored text.
      def update_params
        attrs = character_params
        return attrs unless attrs.key?(:wiki_raw)

        attrs[:wiki_raw].blank? && @character.source_sha256(:wiki_raw) ? attrs.except(:wiki_raw) : attrs
      end

      def character_params
        params.require(:character).permit(
          :granblue_id, :name_en, :name_jp, :rarity, :element,
          :proficiency1, :proficiency2, :gender, :race1, :race2,
          :flb, :ulb, :transcendence, :max_transcendence_stage, :special, :season,
          :style_swap, :gender_variants, :style_name_en, :style_name_jp,
          :min_hp, :max_hp, :max_hp_flb, :max_hp_ulb, :max_hp_transcendence,
          :min_atk, :max_atk, :max_atk_flb, :max_atk_ulb, :max_atk_transcendence,
          :base_da, :base_ta, :ougi_ratio, :ougi_ratio_flb,
          :release_date, :flb_date, :ulb_date, :transcendence_date,
          :wiki_en, :wiki_ja, :wiki_raw, :gamewith, :kamigame,
          nicknames_en: [], nicknames_jp: [], character_id: [], series: []
        )
      end
    end
  end
end

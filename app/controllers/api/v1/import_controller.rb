# frozen_string_literal: true

module Api
  module V1
    ##
    # ImportController is responsible for importing game data (e.g. deck data)
    # and creating a new Party along with associated records (job, characters, weapons, summons, etc.).
    #
    # The controller expects a JSON payload whose top-level key is "import". If not wrapped,
    # the controller will wrap the raw data automatically.
    #
    # @example Valid payload structure
    #   {
    #     "import": {
    #       "deck": { "name": "My Party", ... },
    #       "pc": { "job": { "master": { "name": "Warrior" } }, ... }
    #     }
    #   }
    class ImportController < Api::V1::ApiController
      ELEMENT_MAPPING = {
        0 => nil,
        1 => 2, # Fire -> Fire
        2 => 3, # Water -> Water
        3 => 4, # Earth -> Earth
        4 => 1, # Wind -> Wind
        5 => 6, # Light -> Light
        6 => 5  # Dark -> Dark
      }.freeze

      # GBF series_id to CharacterSeries slug mapping
      GBF_SERIES_TO_SLUG = {
        1 => 'summer',
        2 => 'yukata',
        3 => 'valentine',
        4 => 'halloween',
        5 => 'holiday',
        6 => 'zodiac',
        7 => 'grand',
        8 => 'fantasy',
        9 => 'collab',
        10 => 'eternal',
        11 => 'evoker',
        12 => 'saint',
        13 => 'formal'
      }.freeze

      # GBF series_id to WeaponSeries slug mapping
      GBF_WEAPON_SERIES_TO_SLUG = {
        1 => 'seraphic',
        2 => 'grand',
        3 => 'dark-opus',
        4 => 'revenant',
        5 => 'primal',
        6 => 'beast',
        7 => 'regalia',
        8 => 'omega',
        9 => 'olden-primal',
        10 => 'hollowsky',
        11 => 'xeno',
        12 => 'rose',
        13 => 'ultima',
        14 => 'bahamut',
        15 => 'epic',
        16 => 'cosmos',
        17 => 'superlative',
        18 => 'vintage',
        19 => 'class-champion',
        20 => 'replica',
        21 => 'relic',
        22 => 'rusted',
        23 => 'sephira',
        24 => 'vyrmament',
        25 => 'upgrader',
        26 => 'astral',
        27 => 'draconic',
        28 => 'eternal-splendor',
        29 => 'ancestral',
        30 => 'new-world-foundation',
        31 => 'ennead',
        32 => 'militis',
        33 => 'malice',
        34 => 'menace',
        35 => 'illustrious',
        36 => 'proven',
        37 => 'revans',
        38 => 'world',
        39 => 'exo',
        40 => 'draconic-providence',
        41 => 'celestial',
        42 => 'omega-rebirth',
        43 => 'collab',
        44 => 'destroyer'
      }.freeze

      # GBF series_id to SummonSeries slug mapping
      GBF_SUMMON_SERIES_TO_SLUG = {
        1 => 'providence',
        2 => 'genesis',
        3 => 'magna',
        4 => 'optimus',
        5 => 'demi-optimus',
        6 => 'archangel',
        7 => 'arcarum',
        8 => 'epic',
        9 => 'carbuncle',
        10 => 'dynamis',
        12 => 'cryptid',
        13 => 'six-dragons',
        14 => 'summer',
        15 => 'yukata',
        16 => 'holiday',
        17 => 'collab',
        18 => 'bellum',
        19 => 'crest',
        20 => 'robur'
      }.freeze

      # POST /import `kind` values. Without a kind the body is a game deck.
      SOLOMONIS_RUN = 'solomonis_run'
      SOLOMONIS_PARTY = 'solomonis_party'
      # Cap on POST /import bodies, checked before parsing. A game deck is
      # around 100 KB; a Solomonis report with up to 300 guidebook entries and
      # an optional party deck stays well under it too.
      MAX_BODY_BYTES = 1.megabyte

      before_action :ensure_editor_role, only: %i[weapons summons characters]

      ##
      # Processes an import request.
      #
      # It reads and parses the raw JSON, wraps the data under the "import" key if necessary,
      # transforms the deck data using BaseDeckTransformer, validates that the transformed data
      # contains required fields, and then creates a new Party record (and its associated objects)
      # inside a transaction.
      #
      # @return [void] Renders JSON response with a party shortcode or an error message.
      def create
        Rails.logger.info '[IMPORT] Checking input...'

        if request.raw_post.bytesize > MAX_BODY_BYTES
          return render json: { error: 'payload_too_large' }, status: :payload_too_large
        end

        body = parse_request_body
        return unless body
        return import_by_kind(body) if body.is_a?(Hash) && body.key?('kind')

        raw_params = body['import']
        unless raw_params.is_a?(Hash)
          Rails.logger.error "[IMPORT] 'import' key is missing or not a hash."
          return render json: { error: 'Invalid JSON data' }, status: :unprocessable_content
        end

        unless raw_params['deck'].is_a?(Hash) &&
               raw_params['deck'].key?('pc') &&
               raw_params['deck'].key?('npc')
          Rails.logger.error '[IMPORT] Deck data incomplete or missing.'
          return render json: { error: 'Invalid deck data' }, status: :unprocessable_content
        end

        Rails.logger.info '[IMPORT] Starting import...'

        return if performed? # Rendered an error response already

        party = nil
        warnings = []
        ActiveRecord::Base.transaction do
          party = Party.create!(
            user: current_user,
            visibility: resolve_import_visibility(body),
            name: body['name'].presence,
            last_updated: Time.current
          )
          deck_data = raw_params
          warnings = process_data(party, deck_data)

          # Apply raid - explicit selection takes priority over auto-detect
          if body['raid_id'].present?
            assign_raid(party, body['raid_id'])
          else
            detect_raid_type(party, deck_data)
          end

          assign_playlists(party, body['playlist_ids']) if body['playlist_ids'].present?
        end

        render json: { shortcode: party.shortcode, party_id: party.id, warnings: warnings }, status: :created
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.error "[IMPORT] Import failed: #{e.class}: #{e.message}"
        report_unexpected_exception(e, phase: 'import_create')
        render json: { error: 'invalid_data', details: e.record.errors.full_messages },
               status: :unprocessable_content
      rescue StandardError => e
        Rails.logger.error "[IMPORT] Import failed: #{e.class}: #{e.message}"
        Rails.logger.error e.backtrace&.first(10)&.join("\n")
        report_unexpected_exception(e, phase: 'import_create')
        render json: { error: 'Import failed due to an unexpected error. Please try again.' }, status: :unprocessable_content
      end

      def weapons
        Rails.logger.info '[IMPORT] Checking weapon gamedata input...'

        body = parse_request_body
        return unless body

        weapon = Weapon.find_by(granblue_id: body['id'])
        unless weapon
          Rails.logger.error "[IMPORT] Weapon not found with ID: #{body['id']}"
          return render json: { error: 'Weapon not found' }, status: :not_found
        end

        lang = params[:lang]
        unless %w[en jp].include?(lang)
          Rails.logger.error "[IMPORT] Invalid language: #{lang}"
          return render json: { error: 'Invalid language' }, status: :unprocessable_content
        end

        begin
          weapon.update!(
            "game_raw_#{lang}" => body
          )

          # Parse series_id and assign WeaponSeries
          series_id = Granblue::GamePayload.series_id(body)
          if series_id
            slug = GBF_WEAPON_SERIES_TO_SLUG[series_id.to_i]
            if slug
              series_record = WeaponSeries.find_by(slug: slug)
              if series_record && weapon.weapon_series != series_record
                weapon.update!(weapon_series: series_record)
                Rails.logger.info "[IMPORT] Set series '#{slug}' for weapon #{weapon.granblue_id}"
              end
            end
          end

          render json: { message: 'Weapon gamedata updated successfully' }, status: :ok
        rescue StandardError => e
          Rails.logger.error "[IMPORT] Failed to update weapon gamedata (#{e.class})"
          report_unexpected_exception(e, phase: 'gamedata_update')
          render json: { error: 'Could not store the game data' }, status: :unprocessable_content
        end
      end

      def summons
        Rails.logger.info '[IMPORT] Checking summon gamedata input...'

        body = parse_request_body
        return unless body

        summon = Summon.find_by(granblue_id: body['id'])
        unless summon
          Rails.logger.error "[IMPORT] Summon not found with ID: #{body['id']}"
          return render json: { error: 'Summon not found' }, status: :not_found
        end

        lang = params[:lang]
        unless %w[en jp].include?(lang)
          Rails.logger.error "[IMPORT] Invalid language: #{lang}"
          return render json: { error: 'Invalid language' }, status: :unprocessable_content
        end

        begin
          summon.update!(
            "game_raw_#{lang}" => body
          )

          # Parse series_id and assign SummonSeries
          series_id = Granblue::GamePayload.series_id(body)
          if series_id
            slug = GBF_SUMMON_SERIES_TO_SLUG[series_id.to_i]
            if slug
              series_record = SummonSeries.find_by(slug: slug)
              if series_record && summon.summon_series != series_record
                summon.update!(summon_series: series_record)
                Rails.logger.info "[IMPORT] Set series '#{slug}' for summon #{summon.granblue_id}"
              end
            end
          end

          render json: { message: 'Summon gamedata updated successfully' }, status: :ok
        rescue StandardError => e
          Rails.logger.error "[IMPORT] Failed to update summon gamedata (#{e.class})"
          report_unexpected_exception(e, phase: 'gamedata_update')
          render json: { error: 'Could not store the game data' }, status: :unprocessable_content
        end
      end

      ##
      # Updates character gamedata from JSON blob.
      #
      # @return [void] Renders JSON response with success or error message.
      def characters
        Rails.logger.info '[IMPORT] Checking character gamedata input...'

        body = parse_request_body
        return unless body

        granblue_id = Granblue::GamePayload.granblue_id(body)
        style_row = Granblue::GamePayload.style(body) == '2'
        character = gamedata_character(body)
        if style_row && character.nil? && Character.exists?(granblue_id: granblue_id)
          Rails.logger.error "[IMPORT] Style row missing for character #{granblue_id}"
          return render json: { error: "style row missing for #{granblue_id}" }, status: :unprocessable_content
        end
        unless character
          Rails.logger.error "[IMPORT] Character not found with ID: #{granblue_id}"
          return render json: { error: 'Character not found' }, status: :not_found
        end

        lang, error = gamedata_language(body)
        return render json: error, status: :unprocessable_content if error

        begin
          # Stored as the character's game_raw_<lang> source (D35), dated now.
          character.update!(
            "game_raw_#{lang}" => body,
            "game_raw_#{lang}_fetched_at" => Time.current
          )

          # Parse series_id and create CharacterSeriesMembership (master.series_id is a list)
          series_id = Granblue::GamePayload.series_id(body)
          if series_id
            slug = GBF_SERIES_TO_SLUG[series_id.to_i]
            if slug
              series_record = CharacterSeries.find_by(slug: slug)
              if series_record && !character.character_series_records.include?(series_record)
                character.character_series_memberships.create!(character_series: series_record)
                Rails.logger.info "[IMPORT] Added series '#{slug}' to character #{character.granblue_id}"
              end
            end
          end

          render json: { message: 'Character gamedata updated successfully' }, status: :ok
        rescue StandardError => e
          Rails.logger.error "[IMPORT] Failed to update character gamedata (#{e.class})"
          report_unexpected_exception(e, phase: 'gamedata_update')
          render json: { error: 'Could not store the game data' }, status: :unprocessable_content
        end
      end

      private

      # The row a character detail payload belongs to. A style shift shares its
      # granblue_id with the base character, so the payload's style picks the row.
      # A style 2 payload never lands on the base row; anything else falls back to
      # any row with the id.
      def gamedata_character(body)
        granblue_id = Granblue::GamePayload.granblue_id(body)
        return if granblue_id.blank?
        return Character.find_by(granblue_id: granblue_id, style_swap: true) if Granblue::GamePayload.style(body) == '2'

        Character.find_by(granblue_id: granblue_id, style_swap: false) || Character.find_by(granblue_id: granblue_id)
      end

      # The payload's language, judged from its skill names (the game answers in the account's
      # language); lang decides only a payload that can't be judged, and a lang that disagrees
      # is refused. → [lang, nil] or [nil, error body].
      def gamedata_language(body)
        detected = Granblue::GamePayload.language(body)
        requested = params[:lang].presence_in(%w[en jp])
        if detected && requested && detected != requested
          Rails.logger.error "[IMPORT] lang=#{requested}, but the payload reads as #{detected}"
          return [nil, { error: 'language_mismatch', message: "This game data is in #{detected}, not #{requested}" }]
        end
        return [detected || requested, nil] if detected || requested

        Rails.logger.error '[IMPORT] Invalid language'
        [nil, { error: 'Invalid language' }]
      end

      def import_by_kind(body)
        case body['kind']
        when SOLOMONIS_RUN
          import_solomonis_run(body)
        when SOLOMONIS_PARTY
          import_solomonis_party(body)
        else
          render json: { error: 'unknown_kind', message: 'kind must be solomonis_party, solomonis_run or left out' },
                 status: :unprocessable_content
        end
      end

      ##
      # Imports an Evoking Solomonis run from the game's expedition report.
      # A report already imported by this user is a 409 unless update_existing
      # is true, which updates that run in place.
      def import_solomonis_run(body)
        return render_unauthorized_response unless current_user

        data = body['solomonis']
        Processors::SolomonisProcessor.validate!(data)
        existing = imported_run(Processors::SolomonisProcessor.report_id(data))
        return render_duplicate_report(existing) if existing && body['update_existing'] != true

        party = existing || Party.new(user: current_user, visibility: resolve_import_visibility(body))
        apply_solomonis_party_options(party, body)

        warnings = []
        ActiveRecord::Base.transaction do
          processor = Processors::SolomonisProcessor.new(party, data)
          processor.process
          warnings = processor.warnings
          assign_playlists(party, body['playlist_ids']) if body['playlist_ids'].present?
        end

        render json: { party_id: party.id, shortcode: party.shortcode, warnings: warnings }, status: :created
      rescue Processors::SolomonisProcessor::ImportError => e
        render json: { error: e.code, message: e.message }, status: :unprocessable_content
      rescue ActiveRecord::RecordNotUnique
        # Another request imported the same report first.
        existing = imported_run(Processors::SolomonisProcessor.report_id(data))
        raise unless existing

        render_duplicate_report(existing)
      end

      ##
      # Imports an Evoking Solomonis party from the game's party deck. A new
      # party each time, like the normal deck import.
      def import_solomonis_party(body)
        return render_unauthorized_response unless current_user

        data = body['solomonis']
        Processors::SolomonisPartyProcessor.validate!(data)
        party = Party.new(user: current_user, visibility: resolve_import_visibility(body))
        apply_solomonis_party_options(party, body)

        warnings = []
        ActiveRecord::Base.transaction do
          processor = Processors::SolomonisPartyProcessor.new(party, data)
          processor.process
          warnings = processor.warnings
          assign_playlists(party, body['playlist_ids']) if body['playlist_ids'].present?
        end

        render json: { party_id: party.id, shortcode: party.shortcode, warnings: warnings }, status: :created
      rescue Processors::SolomonisProcessor::ImportError => e
        render json: { error: e.code, message: e.message }, status: :unprocessable_content
      end

      # The current user's run imported from this report, if any. The
      # expedition's user is always the party's owner; checked again anyway.
      def imported_run(report_id)
        party = SolomonisExpedition.find_by(user_id: current_user.id, game_report_id: report_id)&.party
        party if party&.user_id == current_user.id
      end

      def render_duplicate_report(party)
        render json: { error: 'duplicate_report', party_id: party.id, shortcode: party.shortcode },
               status: :conflict
      end

      # Name and visibility only change when sent, so a re-import keeps the
      # user's edits.
      def apply_solomonis_party_options(party, body)
        name = body['name']
        party.name = name.squish.truncate(Solomonis::ReportParser::NAME_MAX_LENGTH, omission: '') if name.is_a?(String) && name.present?
        visibility = requested_visibility(body)
        party.visibility = visibility if party.persisted? && visibility
      end

      def resolve_import_visibility(body)
        requested_visibility(body) || current_user.default_import_visibility
      end

      # The body's visibility (1, 2 or 3, as a number or digit string), or nil
      # when it's missing or anything else.
      def requested_visibility(body)
        value = body['visibility']
        value = value.to_i if value.is_a?(String) && value.match?(/\A\d\z/)
        value if [1, 2, 3].include?(value)
      end

      ##
      # Reads and parses the raw JSON request body.
      #
      # @return [Hash] Parsed JSON data.
      # @raise [JSON::ParserError] If the JSON is invalid.
      # The request body as a Hash; anything else (an array, a number, null) renders a 422 and
      # returns nil.
      def parse_request_body
        body = JSON.parse(request.raw_post)
        return body if body.is_a?(Hash)

        Rails.logger.error "[IMPORT] Body is not a JSON object (#{body.class})"
        render json: { error: 'Invalid JSON data' }, status: :unprocessable_content
        nil
      rescue JSON::ParserError
        Rails.logger.error '[IMPORT] Invalid JSON'
        render json: { error: 'Invalid JSON data' }, status: :bad_request
        nil
      end

      ##
      # Ensures that the provided data is wrapped under an "import" key.
      #
      # @param data [Hash] The parsed JSON data.
      # @return [Hash] Data wrapped under the "import" key.
      def wrap_import_data(data)
        data.key?('import') ? data : { 'import' => data }
      end

      ##
      # Processes the deck data using processors.
      #
      # @param party [Party] The party to insert data into
      # @param data [Hash] The wrapped data.
      # @return [Array<Hash>] Warnings collected from the processors.
      def process_data(party, data)
        Rails.logger.info '[IMPORT] Transforming deck data'

        processors = [
          Processors::JobProcessor,
          Processors::CharacterProcessor,
          Processors::SummonProcessor,
          Processors::WeaponProcessor,
          Processors::BulletProcessor
        ].map { |klass| klass.new(party, data) }

        processors.each(&:process)
        processors.flat_map(&:warnings)
      end

      ##
      # Assigns an explicitly selected raid to the party.
      #
      # @param party [Party] the party record.
      # @param raid_identifier [String] the raid UUID or slug from the request body.
      # @return [void]
      def assign_raid(party, raid_identifier)
        raid = Raid.find_by(id: raid_identifier) || Raid.find_by(slug: raid_identifier)
        return unless raid

        party.update!(raid: raid, extra: raid.group.extra)
      end

      ##
      # Assigns the party to one or more playlists owned by the current user.
      #
      # @param party [Party] the party record.
      # @param playlist_ids [Array<String>] the playlist IDs from the request body.
      # @return [void]
      def assign_playlists(party, playlist_ids)
        Array(playlist_ids).each do |playlist_id|
          playlist = current_user.playlists.find_by(id: playlist_id)
          next unless playlist

          PlaylistParty.find_or_create_by!(playlist: playlist, party: party)
        end
      end

      ##
      # Detects the raid type based on weapon and character counts and sets the raid accordingly.
      # - 10 weapons AND 5 characters → Farming raid
      # - 13 weapons AND 5 characters → Farming (V2) raid
      # - 13 weapons AND 7 characters → Unlimited raid
      #
      # @param party [Party] the party record.
      # @param data [Hash] the deck data.
      # @return [void]
      def detect_raid_type(party, data)
        weapons_count = data.dig('deck', 'pc', 'weapons')&.size.to_i
        characters_count = data.dig('deck', 'npc')&.size.to_i

        raid = if weapons_count == 10 && characters_count == 5
                 Raid.find_by(slug: 'farming')
               elsif weapons_count == 13 && characters_count == 5
                 Raid.find_by(slug: 'farming-v2')
               elsif weapons_count == 13 && characters_count == 7
                 Raid.joins(:group).find_by(raid_groups: { unlimited: true })
               end

        return unless raid

        party.update!(raid: raid, extra: raid.group.extra)
      end
    end
  end
end

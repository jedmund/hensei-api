# frozen_string_literal: true

module Api
  module V1
    ##
    # Imports game data the browser extension captures.
    #
    # - POST /import creates a party from a game deck (DeckImport), or from an
    #   Evoking Solomonis report or deck when the body has a kind.
    # - POST /import/{weapons,summons,characters} store a detail payload on its
    #   catalog row (GameDataImport); editors only.
    #
    # The services do the work; this controller checks the body, signs in and
    # renders.
    #
    # @example Deck import body
    #   { "import": { "deck": { "pc": { ... }, "npc": { ... } } }, "raid_id": "...", "visibility": 2 }
    class ImportController < Api::V1::ApiController
      # POST /import `kind` values. Without a kind the body is a game deck.
      SOLOMONIS_RUN = 'solomonis_run'
      SOLOMONIS_PARTY = 'solomonis_party'
      # Cap on POST /import bodies, checked before parsing. A game deck is
      # around 100 KB; a Solomonis report with up to 300 guidebook entries and
      # an optional party deck stays well under it too.
      MAX_BODY_BYTES = 1.megabyte

      before_action :ensure_editor_role, only: %i[weapons summons characters]

      ##
      # Creates a party from the body: a game deck, or a Solomonis capture by kind.
      #
      # @return [void] renders the party's shortcode and id, or an error
      def create
        Rails.logger.info '[IMPORT] Checking input...'

        return render json: { error: 'payload_too_large' }, status: :content_too_large if request.raw_post.bytesize > MAX_BODY_BYTES

        body = parse_request_body
        return unless body
        return import_by_kind(body) if body.key?('kind')

        import_deck(body)
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

      # Stores a weapon detail payload.
      def weapons
        import_game_data(:weapon)
      end

      # Stores a summon detail payload.
      def summons
        import_game_data(:summon)
      end

      # Stores a character detail payload, on the style row for a style shift.
      def characters
        import_game_data(:character)
      end

      private

      def import_deck(body)
        error = DeckImport.payload_error(body)
        return render json: { error: error }, status: :unprocessable_content if error

        party, warnings = DeckImport.new(current_user, body).call
        render json: { shortcode: party.shortcode, party_id: party.id, warnings: warnings }, status: :created
      end

      def import_game_data(kind)
        Rails.logger.info "[IMPORT] Checking #{kind} gamedata input..."

        body = parse_request_body
        return unless body

        GameDataImport.new(kind, body, lang: params[:lang]).call
        render json: { message: "#{kind.to_s.capitalize} gamedata updated successfully" }, status: :ok
      rescue GameDataImport::Rejected => e
        render json: { error: e.message }, status: e.status
      rescue GameDataImport::StoreFailed => e
        report_unexpected_exception(e.cause, phase: 'gamedata_update')
        render json: { error: 'Could not store the game data' }, status: :unprocessable_content
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

        options = PartyImportOptions.new(current_user, body)
        party = existing || Party.new(user: current_user, visibility: options.visibility)
        process_solomonis(Processors::SolomonisProcessor, party, data, body, options)
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
        options = PartyImportOptions.new(current_user, body)
        party = Party.new(user: current_user, visibility: options.visibility)
        process_solomonis(Processors::SolomonisPartyProcessor, party, data, body, options)
      rescue Processors::SolomonisProcessor::ImportError => e
        render json: { error: e.code, message: e.message }, status: :unprocessable_content
      end

      def process_solomonis(processor_class, party, data, body, options)
        apply_solomonis_party_options(party, body, options)

        warnings = []
        ActiveRecord::Base.transaction do
          processor = processor_class.new(party, data)
          processor.process
          warnings = processor.warnings
          options.assign_playlists(party)
        end

        render json: { party_id: party.id, shortcode: party.shortcode, warnings: warnings }, status: :created
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
      def apply_solomonis_party_options(party, body, options)
        name = body['name']
        party.name = name.squish.truncate(Solomonis::ReportParser::NAME_MAX_LENGTH, omission: '') if name.is_a?(String) && name.present?
        visibility = options.requested_visibility
        party.visibility = visibility if party.persisted? && visibility
      end

      # The request body as a Hash; anything else (an array, a number, null)
      # renders a 422 and returns nil. Invalid JSON renders a 400.
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
    end
  end
end

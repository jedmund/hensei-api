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
        1 => 4,
        2 => 2,
        3 => 3,
        4 => 1,
        5 => 6,
        6 => 5
      }.freeze

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

        body = parse_request_body
        return unless body

        raw_params = body['import']
        unless raw_params.is_a?(Hash)
          Rails.logger.error "[IMPORT] 'import' key is missing or not a hash."
          return render json: { error: 'Invalid JSON data' }, status: :unprocessable_content
        end

        unless raw_params['deck'].is_a?(Hash) &&
          raw_params['deck'].key?('pc') &&
          raw_params['deck'].key?('npc')
          Rails.logger.error "[IMPORT] Deck data incomplete or missing."
          return render json: { error: 'Invalid deck data' }, status: :unprocessable_content
        end

        Rails.logger.info '[IMPORT] Starting import...'

        return if performed? # Rendered an error response already

        party = Party.create(user: current_user)
        deck_data = raw_params['import']
        process_data(party, deck_data)

        render json: { shortcode: party.shortcode }, status: :created
      rescue StandardError => e
        render json: { error: e.message }, status: :unprocessable_content
      end

      private

      ##
      # Reads and parses the raw JSON request body.
      #
      # @return [Hash] Parsed JSON data.
      # @raise [JSON::ParserError] If the JSON is invalid.
      def parse_request_body
        raw_body = request.raw_post
        JSON.parse(raw_body)
      rescue JSON::ParserError => e
        Rails.logger.error "[IMPORT] Invalid JSON: #{e.message}"
        render json: { error: 'Invalid JSON data' }, status: :bad_request and return
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
      # @return [Hash] The transformed deck data.
      def process_data(party, data)
        Rails.logger.info '[IMPORT] Transforming deck data'

        Processors::JobProcessor.new(party, data).process
        Processors::CharacterProcessor.new(party, data).process
        Processors::SummonProcessor.new(party, data).process
        Processors::WeaponProcessor.new(party, data).process
      end
    end
  end
end

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

      before_action :ensure_admin_role, only: %i[weapons summons characters]

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
          Rails.logger.error '[IMPORT] Deck data incomplete or missing.'
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
            "game_raw_#{lang}" => body.to_json
          )
          render json: { message: 'Weapon gamedata updated successfully' }, status: :ok
        rescue StandardError => e
          Rails.logger.error "[IMPORT] Failed to update weapon gamedata: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_content
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
            "game_raw_#{lang}" => body.to_json
          )
          render json: { message: 'Summon gamedata updated successfully' }, status: :ok
        rescue StandardError => e
          Rails.logger.error "[IMPORT] Failed to update summon gamedata: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_content
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

        character = Character.find_by(granblue_id: body['id'])
        unless character
          Rails.logger.error "[IMPORT] Character not found with ID: #{body['id']}"
          return render json: { error: 'Character not found' }, status: :not_found
        end

        lang = params[:lang]
        unless %w[en jp].include?(lang)
          Rails.logger.error "[IMPORT] Invalid language: #{lang}"
          return render json: { error: 'Invalid language' }, status: :unprocessable_content
        end

        begin
          character.update!(
            "game_raw_#{lang}" => body.to_json
          )
          render json: { message: 'Character gamedata updated successfully' }, status: :ok
        rescue StandardError => e
          Rails.logger.error "[IMPORT] Failed to update character gamedata: #{e.message}"
          render json: { error: e.message }, status: :unprocessable_content
        end
      end

      private

      ##
      # Ensures the current user has admin role (role 9).
      # Renders an error if the user is not an admin.
      #
      # @return [void]
      def ensure_admin_role
        return if current_user&.role == 9

        Rails.logger.error "[IMPORT] Unauthorized access attempt by user #{current_user&.id}"
        render json: { error: 'Unauthorized' }, status: :unauthorized
      end

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

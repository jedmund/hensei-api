module Granblue
  module Transformers
    # Transforms raw game character data into standardized format for database import.
    # Handles character stats, uncap levels, transcendence, and perpetuity rings.
    #
    # @example Transforming character data
    #   data = { "master" => { "name" => "Katalina", "id" => "3040001000" },
    #            "param" => { "evolution" => 3, "phase" => 1 } }
    #   transformer = CharacterTransformer.new(data)
    #   result = transformer.transform
    #   # => [{ name: "Katalina", id: "3040001000", uncap: 3, transcend: 1 }]
    #
    # @note Expects data with "master" and "param" nested objects for each character
    # @note Will filter out characters with missing or invalid required attributes
    #
    # @see BaseTransformer For base transformation functionality
    class CharacterTransformer < BaseTransformer
      # Transforms raw game character data into a standardized format
      # @return [Array<Hash>] Array of character hashes with standardized attributes:
      #   @option character [String] :name Character's name
      #   @option character [String] :id Character's ID
      #   @option character [Integer] :uncap Character's uncap level
      #   @option character [Boolean] :ringed Whether character has perpetuity rings
      #   @option character [Integer] :transcend Character's transcendence phase level
      def transform
        # Log start of transformation process
        Rails.logger.info "[TRANSFORM] Starting CharacterTransformer#transform"

        # Validate that the input data is a Hash
        unless data.is_a?(Hash)
          Rails.logger.error "[TRANSFORM] Invalid character data structure"
          return []
        end

        characters = []
        # Iterate through each character data entry
        data.each_value do |char_data|
          # Skip entries missing required master/param data
          next unless char_data['master'] && char_data['param']

          master = char_data['master']
          param = char_data['param']

          Rails.logger.debug "[TRANSFORM] Processing character: #{master['name']}"

          # Build base character hash with required attributes
          character = {
            name: master['name'], # Character's display name
            id: master['id'], # Unique identifier
            uncap: param['evolution'].to_i # Current uncap level
          }

          Rails.logger.debug "[TRANSFORM] Base character data: #{character}"

          # Add perpetuity ring status if present
          if param['has_npcaugment_constant']
            character[:ringed] = true
            Rails.logger.debug "[TRANSFORM] Character is ringed"
          end

          # Add transcendence level if present (stored as 'phase' in raw data)
          phase = param['phase'].to_i
          if phase&.positive?
            character[:transcend] = phase
            Rails.logger.debug "[TRANSFORM] Character has transcendence: #{phase}"
          end

          # Only add characters with valid IDs to result set
          characters << character unless master['id'].nil?
          Rails.logger.info "[TRANSFORM] Successfully processed character #{character[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{characters.length} characters"
        characters
      end
    end
  end
end

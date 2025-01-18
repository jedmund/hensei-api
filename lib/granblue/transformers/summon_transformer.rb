# frozen_string_literal: true

module Granblue
  module Transformers
    # Transforms raw game summon data into standardized format for database import.
    # Handles summon stats, uncap levels, transcendence, and quick summon status.
    #
    # @example Transforming summon data
    #   data = {
    #     "master" => { "name" => "Bahamut", "id" => "2040003000" },
    #     "param" => { "evolution" => 5, "level" => 200 }
    #   }
    #   transformer = SummonTransformer.new(data, "2040003000")
    #   result = transformer.transform
    #   # => [{ name: "Bahamut", id: "2040003000", uncap: 5, transcend: 1, qs: true }]
    #
    # @note Expects data with "master" and "param" nested objects for each summon
    # @note Handles quick summon status if ID matches provided quick_summon_id
    #
    # @see BaseTransformer For base transformation functionality
    class SummonTransformer < BaseTransformer
      # @return [Array<Integer>] Level thresholds for determining transcendence level
      TRANSCENDENCE_LEVELS = [210, 220, 230, 240].freeze

      # Creates a new summon transformer
      # @param data [Object] Raw summon data to transform
      # @param quick_summon_id [String, nil] ID of the current quick summon
      # @param options [Hash] Additional transformation options
      # @option options [String] :language ('en') Language for names
      # @option options [Boolean] :debug (false) Enable debug logging
      # @return [void]
      def initialize(data, quick_summon_id = nil, options = {})
        super(data, options)
        @quick_summon_id = quick_summon_id
        Rails.logger.info "[TRANSFORM] Initializing SummonTransformer with quick_summon_id: #{quick_summon_id}"
      end

      # Transform raw summon data into standardized format
      # @return [Array<Hash>] Array of transformed summon data
      def transform
        Rails.logger.info "[TRANSFORM] Starting SummonTransformer#transform"

        # Validate that input data is a Hash
        unless data.is_a?(Hash)
          Rails.logger.error "[TRANSFORM] Invalid summon data structure"
          Rails.logger.error "[TRANSFORM] Data class: #{data.class}"
          return []
        end

        summons = []
        # Process each summon in the data
        data.each_value do |summon_data|
          Rails.logger.debug "[TRANSFORM] Processing summon: #{summon_data['master']['name'] if summon_data['master']}"

          # Extract master and parameter data
          master, param = get_master_param(summon_data)
          unless master && param
            Rails.logger.debug "[TRANSFORM] Skipping summon - missing master or param data"
            next
          end

          # Build base summon hash with required attributes
          summon = {
            name: master['name'], # Summon's display name
            id: master['id'], # Unique identifier
            uncap: param['evolution'].to_i # Current uncap level
          }

          Rails.logger.debug "[TRANSFORM] Base summon data: #{summon}"

          # Add transcendence level for highly uncapped summons
          if summon[:uncap] > 5
            level = param['level'].to_i
            trans = calculate_transcendence_level(level)
            summon[:transcend] = trans
            Rails.logger.debug "[TRANSFORM] Added transcendence level: #{trans}"
          end

          # Mark quick summon status if this summon matches quick_summon_id
          if @quick_summon_id && param['id'].to_s == @quick_summon_id.to_s
            summon[:qs] = true
            Rails.logger.debug "[TRANSFORM] Marked as quick summon"
          end

          summons << summon
          Rails.logger.info "[TRANSFORM] Successfully processed summon #{summon[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{summons.length} summons"
        summons
      end

      private

      # Calculates transcendence level based on summon level
      # @param level [Integer, nil] Current summon level
      # @return [Integer] Calculated transcendence level (1-5)
      def calculate_transcendence_level(level)
        return 1 unless level
        level = 1 + TRANSCENDENCE_LEVELS.count { |cutoff| level > cutoff }
        Rails.logger.debug "[TRANSFORM] Calculated transcendence level: #{level}"
        level
      end
    end
  end
end

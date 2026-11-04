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
        Rails.logger.info '[TRANSFORM] Starting SummonTransformer#transform'

        unless data.is_a?(Hash)
          Rails.logger.error '[TRANSFORM] Invalid summon data structure'
          Rails.logger.error "[TRANSFORM] Data class: #{data.class}"
          return []
        end

        # Determine the maximum index from the keys (assumed to be numeric strings).
        max_index = data.keys.map(&:to_i).max || 0
        # Pre-allocate an array so that key "1" ends up at index 0, etc.
        summons = Array.new(max_index)

        # Process keys sorted numerically.
        data.keys.sort_by(&:to_i).each do |key|
          summon = transform_summon(data[key])
          next unless summon

          # Place the summon in the proper 0-indexed slot.
          summons[key.to_i - 1] = summon
          Rails.logger.info "[TRANSFORM] Successfully processed summon #{summon[:name]}"
        end

        Rails.logger.info "[TRANSFORM] Completed processing #{summons.compact.length} summons"
        summons.compact
      end

      private

      # @param summon_data [Hash] one summon's raw data, with master and param
      # @return [Hash, nil] the transformed summon, or nil without master or param data
      def transform_summon(summon_data)
        Rails.logger.debug { "[TRANSFORM] Processing summon: #{summon_data['master']['name'] if summon_data['master']}" }

        master, param = get_master_param(summon_data)
        unless master && param
          Rails.logger.debug '[TRANSFORM] Skipping summon - missing master or param data'
          return
        end

        # Build the base summon hash, with the transcendence level from the summon's level.
        summon = {
          name: master['name'],
          id: master['id'],
          uncap: param['evolution'].to_i,
          transcend: calculate_transcendence_level(param['level'].to_i)
        }

        # Mark quick summon status if this summon matches quick_summon_id.
        summon[:qs] = true if @quick_summon_id && param['id'].to_s == @quick_summon_id.to_s

        # Include subaura (sub_skill) information if present.
        sub_skill = summon_data['sub_skill']
        summon[:sub_aura] = sub_skill['name'] if sub_skill.is_a?(Hash) && sub_skill['name']
        summon
      end

      # Calculates transcendence level based on summon level
      # @param level [Integer, nil] Current summon level
      # @return [Integer] Calculated transcendence level (1-5)
      def calculate_transcendence_level(level)
        return 1 unless level

        level = 1 + TRANSCENDENCE_LEVELS.count { |cutoff| level > cutoff }
        Rails.logger.debug { "[TRANSFORM] Calculated transcendence level: #{level}" }
        level
      end
    end
  end
end
